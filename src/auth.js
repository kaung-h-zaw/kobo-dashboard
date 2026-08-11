const crypto = require("crypto");

function timingSafeMatch(value, expected) {
  if (!value || !expected) return false;

  const valueBuffer = Buffer.from(value);
  const expectedBuffer = Buffer.from(expected);

  return (
    valueBuffer.length === expectedBuffer.length &&
    crypto.timingSafeEqual(valueBuffer, expectedBuffer)
  );
}

function getBearerToken(request) {
  const authorization = request.get("authorization");
  if (!authorization || !authorization.startsWith("Bearer ")) return undefined;
  return authorization.slice("Bearer ".length);
}

function getDeviceAuthentication(request) {
  const token = request.get("access-token");
  const deviceId = request.get("ID");
  const allowedDeviceId = process.env.ALLOWED_DEVICE_ID;

  const tokenMatches = timingSafeMatch(token, process.env.DEVICE_API_KEY);
  const deviceIdMatches = Boolean(
    deviceId &&
      allowedDeviceId &&
      deviceId.toUpperCase() === allowedDeviceId.toUpperCase(),
  );

  return {
    token,
    deviceId,
    authenticated: tokenMatches || deviceIdMatches,
  };
}

function requireDeviceAuthentication(request, response, next) {
  const result = getDeviceAuthentication(request);

  // Never log the token or configured secrets.
  console.log({
    hasAccessToken: Boolean(result.token),
    deviceId: result.deviceId,
    authenticated: result.authenticated,
  });

  if (!result.authenticated) {
    return response.status(401).json({ error: "Unauthorized" });
  }

  next();
}

function requireAppleSyncAuthentication(request, response, next) {
  const token = getBearerToken(request);

  if (!timingSafeMatch(token, process.env.APPLE_SYNC_SECRET)) {
    return response.status(401).json({ error: "Unauthorized" });
  }

  next();
}

function requireAppleDataAuthentication(request, response, next) {
  const accessToken = request.get("access-token");
  const bearerToken = getBearerToken(request);
  const authenticated =
    timingSafeMatch(accessToken, process.env.DEVICE_API_KEY) ||
    timingSafeMatch(bearerToken, process.env.DEVICE_API_KEY) ||
    timingSafeMatch(bearerToken, process.env.APPLE_SYNC_SECRET);

  if (!authenticated) {
    return response.status(401).json({ error: "Unauthorized" });
  }

  next();
}

function getScreenSigningSecret() {
  return process.env.DEVICE_API_KEY || process.env.APPLE_SYNC_SECRET;
}

function createScreenSignature(filename, expiresAt) {
  const secret = getScreenSigningSecret();
  if (!secret) return undefined;

  return crypto
    .createHmac("sha256", secret)
    .update(`${filename}.${expiresAt}`)
    .digest("hex");
}

function requireScreenSignature(request, response, next) {
  const filename = request.query.v;
  const expiresAt = Number(request.query.expires);
  const providedSignature = request.query.signature;
  const validParameterTypes =
    typeof filename === "string" && typeof providedSignature === "string";
  const expectedSignature = validParameterTypes
    ? createScreenSignature(filename, expiresAt)
    : undefined;
  const currentTime = Math.floor(Date.now() / 1000);

  const authenticated = Boolean(
    validParameterTypes &&
      filename &&
      Number.isInteger(expiresAt) &&
      expiresAt >= currentTime &&
      timingSafeMatch(providedSignature, expectedSignature),
  );

  if (!authenticated) {
    return response.status(401).json({ error: "Unauthorized" });
  }

  next();
}

module.exports = {
  createScreenSignature,
  requireAppleDataAuthentication,
  requireAppleSyncAuthentication,
  requireDeviceAuthentication,
  requireScreenSignature,
  timingSafeMatch,
};
