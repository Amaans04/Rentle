import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    globals: false,
    // DB-integration tests (isolation.test.ts, phase1-*.test.ts) make many
    // real sequential round-trips to Supabase — generous timeouts because a
    // remote CI runner's latency to the DB is meaningfully higher than a
    // local network's, not because anything is actually slow/hanging.
    testTimeout: 30000,
    hookTimeout: 30000,
    setupFiles: ["./tests/setup.ts"],
  },
});
