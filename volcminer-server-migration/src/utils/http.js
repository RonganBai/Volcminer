export class HttpError extends Error {
  constructor(statusCode, message, details) {
    super(message);
    this.name = "HttpError";
    this.statusCode = statusCode;
    this.details = details;
  }
}

export function jsonResponse(res, statusCode, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body)
  });
  res.end(body);
}

export function notFound(res, message = "Not Found") {
  jsonResponse(res, 404, { error: message });
}

export function parseJsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("error", reject);
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8").trim();
      if (!raw) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new HttpError(400, "Invalid JSON body"));
      }
    });
  });
}

export function sendError(res, error) {
  if (error instanceof HttpError) {
    jsonResponse(res, error.statusCode, {
      error: error.message,
      details: error.details ?? null
    });
    return;
  }

  jsonResponse(res, 500, {
    error: "Internal Server Error",
    details: error?.message ?? null
  });
}
