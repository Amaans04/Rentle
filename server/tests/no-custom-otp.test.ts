import { describe, expect, it } from "vitest";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

/**
 * Named regression test for the fake-OTP bug in the prior project
 * (verify-otp.js accepted any 6-digit string as valid — no real code was
 * ever checked). The structural fix: Clerk owns all authentication now, so
 * no custom OTP-verification code should exist anywhere in this repo. This
 * is a static check, not a DB-dependent one — it can and should always run.
 */
function collectSourceFiles(dir: string, out: string[] = []): string[] {
  for (const entry of readdirSync(dir)) {
    if (entry === "node_modules" || entry === "dist" || entry === ".git") continue;
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      collectSourceFiles(full, out);
    } else if (/\.(ts|js)$/.test(entry) && !entry.endsWith(".test.ts")) {
      out.push(full);
    }
  }
  return out;
}

describe("regression: no custom OTP-verification code", () => {
  it("contains zero hand-rolled OTP verification logic (Clerk owns auth entirely)", () => {
    const srcDir = join(import.meta.dirname, "..", "src");
    const files = collectSourceFiles(srcDir);

    const suspiciousPatterns = [
      /otp/i,
      /one[-_]?time[-_]?password/i,
      /verify[-_]?code/i,
    ];

    const offenders: string[] = [];
    for (const file of files) {
      const content = readFileSync(file, "utf-8");
      for (const pattern of suspiciousPatterns) {
        if (pattern.test(content)) {
          offenders.push(file);
          break;
        }
      }
    }

    expect(
      offenders,
      `Found OTP-related code outside Clerk's own SDK — verify this isn't a reintroduction of the fake-OTP bug:\n${offenders.join("\n")}`
    ).toEqual([]);
  });
});
