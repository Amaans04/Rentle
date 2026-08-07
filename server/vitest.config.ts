import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    globals: false,
    // DB-integration tests (isolation.test.ts, phase1-*.test.ts) chain many
    // sequential requests, each involving several real round-trips
    // (resolveOrg's membership lookup, the handler's own ownership
    // re-check, the actual write). A remote CI runner's per-round-trip
    // latency to Supabase runs ~2-3x a local network's, so a chain that's
    // comfortably fast locally can approach a generous-looking timeout in
    // CI — not a hang, just real cumulative network latency.
    testTimeout: 60000,
    hookTimeout: 60000,
    setupFiles: ["./tests/setup.ts"],
    // Run test files sequentially instead of vitest's default parallel
    // workers (this is the Vitest 4 top-level option — poolOptions.
    // singleFork was removed and silently ignored, worth knowing if this
    // needs revisiting). Each PrismaClient opens its own connection pool
    // against Supabase's free-tier pooler, which has a limited number of
    // slots shared across the whole project — fewer concurrent pools
    // reduces pressure on it regardless of the per-client connection_limit
    // set in lib/prisma.ts.
    fileParallelism: false,
  },
});
