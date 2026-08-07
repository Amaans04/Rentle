import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

/**
 * These don't require a live database — they exercise the auth-rejection
 * paths, which run before any DB query. Named regression coverage for "does
 * every route reject missing/invalid credentials" (part of the Phase 0 exit
 * gate), independent of the DB-backed isolation suite in isolation.test.ts.
 */
describe("auth pipeline rejects unauthenticated requests", () => {
  it("GET /me with no Authorization header returns 401", async () => {
    const app = buildApp();
    const response = await app.inject({ method: "GET", url: "/me" });
    expect(response.statusCode).toBe(401);
    expect(response.json()).toMatchObject({ success: false, error: { code: "UNAUTHORIZED" } });
  });

  it("GET /me with a garbage bearer token returns 401, not a crash", async () => {
    const app = buildApp();
    const response = await app.inject({
      method: "GET",
      url: "/me",
      headers: { authorization: "Bearer not-a-real-token" },
    });
    expect(response.statusCode).toBe(401);
  });

  it("GET /internal/health with no shared secret returns 401", async () => {
    const app = buildApp();
    const response = await app.inject({ method: "GET", url: "/internal/health" });
    expect(response.statusCode).toBe(401);
  });

  it("GET /internal/health with the wrong shared secret returns 401", async () => {
    const app = buildApp();
    const response = await app.inject({
      method: "GET",
      url: "/internal/health",
      headers: { "x-internal-secret": "wrong-secret" },
    });
    expect(response.statusCode).toBe(401);
  });

  it("POST /webhooks/clerk with missing svix headers returns 400, not a crash", async () => {
    const app = buildApp();
    const response = await app.inject({
      method: "POST",
      url: "/webhooks/clerk",
      payload: JSON.stringify({ type: "user.created", data: {} }),
      headers: { "content-type": "application/json" },
    });
    expect(response.statusCode).toBe(400);
  });
});
