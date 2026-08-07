export type ApiSuccess<T> = {
  success: true;
  data: T;
  meta?: Record<string, unknown>;
};

export type ApiError = {
  success: false;
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
};

export function ok<T>(data: T, meta?: Record<string, unknown>): ApiSuccess<T> {
  return { success: true, data, ...(meta ? { meta } : {}) };
}

export function fail(code: string, message: string, details?: unknown): ApiError {
  return { success: false, error: { code, message, ...(details !== undefined ? { details } : {}) } };
}

// Common, named error shapes so handlers don't invent ad hoc codes.
export const Errors = {
  unauthorized: () => fail("UNAUTHORIZED", "Authentication required."),
  forbidden: (message = "You do not have access to this resource.") =>
    fail("FORBIDDEN", message),
  notFound: (resource: string) => fail("NOT_FOUND", `${resource} not found.`),
  validation: (details: unknown) => fail("VALIDATION_ERROR", "Invalid request.", details),
  featureLocked: (feature: string) =>
    fail("FEATURE_LOCKED", `"${feature}" is not included in your current plan.`),
  conflict: (message: string) => fail("CONFLICT", message),
};
