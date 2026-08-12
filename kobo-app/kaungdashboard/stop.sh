#!/bin/sh

PID_FILE="/tmp/kaungdashboard.pid"
STOP_FILE="/tmp/kaungdashboard.stop"

touch "${STOP_FILE}"
if [ ! -f "${PID_FILE}" ]; then exit 0; fi
pid="$(cat "${PID_FILE}" 2>/dev/null)"
[ -z "${pid}" ] && exit 0

count=0
while kill -0 "${pid}" 2>/dev/null && [ "${count}" -lt 8 ]; do
    sleep 1
    count=$((count + 1))
done
if kill -0 "${pid}" 2>/dev/null; then kill -TERM "${pid}" 2>/dev/null || true; fi
exit 0
