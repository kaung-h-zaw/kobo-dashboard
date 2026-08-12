import AppKit
import EventKit
import Foundation

struct ReminderPayload: Codable {
    let id: String
    let title: String
    let notes: String?
    let dueDate: String?
    let dueTime: String?
    let priority: Int
    let completed: Bool
    let list: String
}

struct EventPayload: Codable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let calendar: String
    let allDay: Bool
    let location: String?
    let notes: String?
}

struct SyncPayload: Codable {
    let syncedAt: String
    let reminders: [ReminderPayload]
    let events: [EventPayload]
}

struct SyncResponse: Decodable {
    let status: String
    let reminders: Int
    let events: Int
}

struct ReminderAction: Decodable {
    let id: String
    let completed: Bool
}

struct ReminderActionsResponse: Decodable {
    let actions: [ReminderAction]
}

struct ReminderActionAcknowledgement: Encodable {
    let ids: [String]
}

enum SyncError: LocalizedError {
    case missingSecret
    case invalidServerURL
    case permissionDenied(String)
    case eventKit(String)
    case network(String)
    case server(Int)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .missingSecret:
            return "APPLE_SYNC_SECRET is not configured."
        case .invalidServerURL:
            return "KOBO_SERVER_URL is not a valid HTTP or HTTPS URL."
        case .permissionDenied(let service):
            return "Permission denied for \(service). Enable access in System Settings > Privacy & Security."
        case .eventKit(let message):
            return "EventKit read failed: \(message)"
        case .network(let message):
            return "Network request failed: \(message)"
        case .server(let status):
            return "Kobo server returned HTTP \(status)."
        case .malformedResponse:
            return "Kobo server returned a malformed response."
        }
    }
}

struct Configuration {
    let secret: String
    let serverURL: URL
    let timeZone: TimeZone
    let dryRun: Bool
    let permissionsOnly: Bool
    let statusOnly: Bool

    static func load(arguments: [String]) throws -> Configuration {
        let environment = ProcessInfo.processInfo.environment
        let dryRun = arguments.contains("--dry-run")
        let permissionsOnly = arguments.contains("--permissions-only")
        let statusOnly = arguments.contains("--status-only")
        let secret = environment["APPLE_SYNC_SECRET"] ?? ""
        if secret.isEmpty && !dryRun && !permissionsOnly && !statusOnly { throw SyncError.missingSecret }

        let server = environment["KOBO_SERVER_URL"] ?? "https://kobo-dashboard-7ub6.onrender.com"
        guard let serverURL = URL(string: server),
              serverURL.scheme == "http" || serverURL.scheme == "https" else {
            throw SyncError.invalidServerURL
        }

        let identifier = environment["TIMEZONE"] ?? "Asia/Bangkok"
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw SyncError.eventKit("Invalid TIMEZONE: \(identifier)")
        }

        return Configuration(
            secret: secret,
            serverURL: serverURL,
            timeZone: timeZone,
            dryRun: dryRun,
            permissionsOnly: permissionsOnly,
            statusOnly: statusOnly
        )
    }
}

final class AppleDataReader {
    private let store = EKEventStore()
    private var calendar: Calendar
    private let isoFormatter: ISO8601DateFormatter
    private let dueTimeFormatter: DateFormatter

    init(timeZone: TimeZone) {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        dueTimeFormatter = DateFormatter()
        dueTimeFormatter.locale = Locale(identifier: "en_GB")
        dueTimeFormatter.timeZone = timeZone
        dueTimeFormatter.dateFormat = "HH:mm"
    }

    func requestPermissions() async throws {
        let eventsGranted = try await ensureAccess(to: .event, serviceName: "Apple Calendar")
        let remindersGranted = try await ensureAccess(to: .reminder, serviceName: "Apple Reminders")

        guard eventsGranted else { throw SyncError.permissionDenied("Apple Calendar") }
        guard remindersGranted else { throw SyncError.permissionDenied("Apple Reminders") }
    }

    func printAuthorizationStatuses() {
        let eventStatus = EKEventStore.authorizationStatus(for: .event)
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        print("Apple Calendar authorization status: \(statusName(eventStatus))")
        print("Apple Reminders authorization status: \(statusName(reminderStatus))")
    }

    private func ensureAccess(to entityType: EKEntityType, serviceName: String) async throws -> Bool {
        let initialStatus = EKEventStore.authorizationStatus(for: entityType)
        print("\(serviceName) authorization status: \(statusName(initialStatus))")

        guard initialStatus == .notDetermined else {
            return hasReadAccess(initialStatus)
        }

        // Bring this accessory app forward before macOS presents its TCC prompt.
        await MainActor.run {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        let requestGranted: Bool
        if #available(macOS 14.0, *) {
            if entityType == .event {
                requestGranted = try await store.requestFullAccessToEvents()
            } else {
                requestGranted = try await store.requestFullAccessToReminders()
            }
        } else {
            requestGranted = try await requestLegacyAccess(to: entityType)
        }
        print("\(serviceName) full-access request returned: \(requestGranted)")

        let finalStatus = EKEventStore.authorizationStatus(for: entityType)
        print("\(serviceName) authorization status: \(statusName(finalStatus))")
        return hasReadAccess(finalStatus)
    }

    private func hasReadAccess(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    private func statusName(_ status: EKAuthorizationStatus) -> String {
        if #available(macOS 14.0, *) {
            switch status {
            case .notDetermined: return "notDetermined"
            case .restricted: return "restricted"
            case .denied: return "denied"
            case .fullAccess: return "fullAccess"
            case .writeOnly: return "writeOnly"
            case .authorized: return "authorized"
            @unknown default: return "unknown(\(status.rawValue))"
            }
        }

        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        default: return "unknown(\(status.rawValue))"
        }
    }

    private func requestLegacyAccess(to entityType: EKEntityType) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: entityType) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func readReminders() async throws -> [ReminderPayload] {
        let calendars = store.calendars(for: .reminder).filter {
            $0.allowedEntityTypes.contains(.reminder) && !$0.title.isEmpty
        }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars
        )

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { fetched in
                continuation.resume(returning: fetched ?? [])
            }
        }

        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 8, to: startOfToday)!

        return reminders
            .filter { !$0.isCompleted }
            .sorted { left, right in
                let leftDue = dueDate(for: left)
                let rightDue = dueDate(for: right)
                let leftRank = reminderRank(leftDue, today: startOfToday, tomorrow: startOfTomorrow, sevenDays: sevenDaysFromNow)
                let rightRank = reminderRank(rightDue, today: startOfToday, tomorrow: startOfTomorrow, sevenDays: sevenDaysFromNow)
                if leftRank != rightRank { return leftRank < rightRank }
                return (leftDue ?? .distantFuture) < (rightDue ?? .distantFuture)
            }
            .map { reminder in
                let due = dueDate(for: reminder)
                let hasTime = reminder.dueDateComponents?.hour != nil
                return ReminderPayload(
                    id: reminder.calendarItemIdentifier,
                    title: reminder.title ?? "Untitled reminder",
                    notes: reminder.notes,
                    dueDate: due.map(isoFormatter.string),
                    dueTime: hasTime ? due.map(dueTimeFormatter.string) : nil,
                    priority: reminder.priority,
                    completed: false,
                    list: reminder.calendar.title
                )
            }
    }

    func applyReminderActions(_ actions: [ReminderAction]) throws -> [String] {
        var applied: [String] = []
        for action in actions {
            guard let reminder = store.calendarItem(withIdentifier: action.id) as? EKReminder else {
                print("Reminder action skipped; identifier was not found: \(action.id)")
                applied.append(action.id)
                continue
            }
            reminder.isCompleted = action.completed
            reminder.completionDate = action.completed ? Date() : nil
            do {
                try store.save(reminder, commit: true)
                applied.append(action.id)
                print("Reminder completion applied: \(reminder.title ?? action.id) = \(action.completed)")
            } catch {
                throw SyncError.eventKit("Could not update reminder \(action.id): \(error.localizedDescription)")
            }
        }
        return applied
    }

    func readEvents() throws -> [EventPayload] {
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 8, to: start) else {
            throw SyncError.eventKit("Could not create the seven-day event range.")
        }
        let calendars = store.calendars(for: .event).filter {
            $0.allowedEntityTypes.contains(.event) && !$0.title.isEmpty
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)

        return store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                EventPayload(
                    id: event.eventIdentifier ?? event.calendarItemIdentifier,
                    title: event.title ?? "Untitled event",
                    startDate: isoFormatter.string(from: event.startDate),
                    endDate: isoFormatter.string(from: event.endDate),
                    calendar: event.calendar.title,
                    allDay: event.isAllDay,
                    location: event.location,
                    notes: event.notes
                )
            }
    }

    private func dueDate(for reminder: EKReminder) -> Date? {
        guard var components = reminder.dueDateComponents else { return nil }
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)
    }

    private func reminderRank(_ due: Date?, today: Date, tomorrow: Date, sevenDays: Date) -> Int {
        guard let due else { return 4 }
        if due < today { return 0 }
        if due < tomorrow { return 1 }
        if due < sevenDays { return 2 }
        return 3
    }
}

func fetchReminderActions(configuration: Configuration) async throws -> [ReminderAction] {
    let endpoint = configuration.serverURL.appendingPathComponent("api/reminder-actions")
    var request = URLRequest(url: endpoint)
    request.setValue("Bearer \(configuration.secret)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SyncError.malformedResponse }
        guard (200..<300).contains(httpResponse.statusCode) else { throw SyncError.server(httpResponse.statusCode) }
        return try JSONDecoder().decode(ReminderActionsResponse.self, from: data).actions
    } catch let error as SyncError {
        throw error
    } catch _ as DecodingError {
        throw SyncError.malformedResponse
    } catch {
        throw SyncError.network(error.localizedDescription)
    }
}

func acknowledgeReminderActions(_ ids: [String], configuration: Configuration) async throws {
    guard !ids.isEmpty else { return }
    let endpoint = configuration.serverURL.appendingPathComponent("api/reminder-actions/ack")
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(configuration.secret)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30
    request.httpBody = try JSONEncoder().encode(ReminderActionAcknowledgement(ids: ids))
    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SyncError.malformedResponse }
        guard (200..<300).contains(httpResponse.statusCode) else { throw SyncError.server(httpResponse.statusCode) }
    } catch let error as SyncError {
        throw error
    } catch {
        throw SyncError.network(error.localizedDescription)
    }
}

func post(_ payload: SyncPayload, configuration: Configuration) async throws {
    let endpoint = configuration.serverURL.appendingPathComponent("api/apple-sync")
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(configuration.secret)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 60
    request.httpBody = try JSONEncoder().encode(payload)

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.malformedResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SyncError.server(httpResponse.statusCode)
        }
        let decoded = try JSONDecoder().decode(SyncResponse.self, from: data)
        guard decoded.status == "ok" else { throw SyncError.malformedResponse }
    } catch let error as SyncError {
        throw error
    } catch _ as DecodingError {
        throw SyncError.malformedResponse
    } catch {
        throw SyncError.network(error.localizedDescription)
    }
}

func runKoboAppleSync() async -> Int32 {
    do {
        let configuration = try Configuration.load(arguments: CommandLine.arguments)
        let reader = AppleDataReader(timeZone: configuration.timeZone)

        if configuration.statusOnly {
            reader.printAuthorizationStatuses()
            return 0
        }

        try await reader.requestPermissions()

        if configuration.permissionsOnly {
            print("EventKit permission check complete.")
            return 0
        }

        if !configuration.dryRun {
            let actions = try await fetchReminderActions(configuration: configuration)
            if !actions.isEmpty {
                print("Found \(actions.count) pending reminder actions")
                let applied = try reader.applyReminderActions(actions)
                try await acknowledgeReminderActions(applied, configuration: configuration)
            }
        }

        let reminders = try await reader.readReminders()
        let events = try reader.readEvents()
        print("Found \(reminders.count) incomplete reminders")
        print("Found \(events.count) upcoming events")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let payload = SyncPayload(
            syncedAt: formatter.string(from: Date()),
            reminders: reminders,
            events: events
        )

        if configuration.dryRun {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: try encoder.encode(payload), encoding: .utf8) ?? "{}")
            print("Dry run complete; nothing was uploaded.")
        } else {
            try await post(payload, configuration: configuration)
            print("Sync successful")
        }
        return 0
    } catch {
        fputs("Sync failed: \(error.localizedDescription)\n", stderr)
        return 1
    }
}

// A real AppKit lifecycle keeps the main run loop alive while macOS presents
// the Calendar and Reminders TCC consent sheets.
@main
@MainActor
final class KoboAppleSyncApp: NSObject, NSApplicationDelegate {
    private var exitCode: Int32 = 0

    static func main() {
        if CommandLine.arguments.contains("--help") {
            print("Usage: KoboAppleSync [--dry-run | --permissions-only | --status-only]")
            print("--dry-run  Read EventKit and print JSON without posting it.")
            print("--permissions-only  Request/check EventKit access, then exit.")
            print("--status-only  Print EventKit authorization without requesting it.")
            return
        }

        let application = NSApplication.shared
        let delegate = KoboAppleSyncApp()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        exit(delegate.exitCode)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        Task {
            exitCode = await runKoboAppleSync()
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
