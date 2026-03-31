function now() {
  return new Date().toISOString();
}

export const logger = {
  info(message, meta) {
    console.log(JSON.stringify({ level: "info", time: now(), message, ...meta }));
  },
  warn(message, meta) {
    console.warn(JSON.stringify({ level: "warn", time: now(), message, ...meta }));
  },
  error(message, meta) {
    console.error(JSON.stringify({ level: "error", time: now(), message, ...meta }));
  }
};
