export function getEnv(name, fallback = "") {
  const value = process.env[name];
  if (value === undefined || value === null || value.trim().length === 0) {
    return fallback;
  }
  return value.trim();
}

export function getRequiredEnv(name) {
  const value = getEnv(name);
  if (!value) {
    throw new Error(`Missing required env: ${name}`);
  }
  return value;
}

