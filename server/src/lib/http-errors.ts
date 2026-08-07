/**
 * Typed errors route handlers throw; the global error handler in app.ts
 * renders them with the right status code and api-response envelope. Using
 * a dedicated class (checked via `instanceof`) instead of bolting
 * `statusCode` onto a plain Error keeps that check unambiguous.
 */
export class HttpError extends Error {
  statusCode: number;
  code: string;
  details?: unknown;

  constructor(statusCode: number, code: string, message: string, details?: unknown) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

export class ValidationError extends HttpError {
  constructor(details: unknown) {
    super(400, "VALIDATION_ERROR", "Invalid request.", details);
  }
}

/** Thrown by the ownership re-derivation check every resource-ID route does. */
export class NotFoundError extends HttpError {
  constructor(resource: string) {
    super(404, "NOT_FOUND", `${resource} not found.`);
  }
}

export class ConflictError extends HttpError {
  constructor(message: string) {
    super(409, "CONFLICT", message);
  }
}
