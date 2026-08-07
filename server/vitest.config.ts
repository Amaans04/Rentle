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
    // Run all test files in one process instead of vitest's default
    // parallel worker pool. Each PrismaClient opens its own connection
    // pool against Supabase's free-tier pooler, which has a limited number
    // of slots shared across the whole project — multiple test-file workers
    // each opening their own pool can exhaust it and hang rather than error
    // cleanly. One process + the shared `prisma` singleton (see
    // tests/isolation.test.ts and tests/phase1-*.test.ts) keeps total
    // connections bounded regardless of how many test files exist.
    pool: "forks",
    poolOptions: {
      forks: { singleFork: true },
    },
  },
});
