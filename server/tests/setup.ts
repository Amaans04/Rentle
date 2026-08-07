// Runs before any test file is imported. Provides safe, non-secret dummy
// values for env vars that aren't set, so `npm test` works without a real
// .env in this repo's early state. Real credentials (when present in the
// environment/.env) always win — this never overrides an already-set var.
const defaults: Record<string, string> = {
  DATABASE_URL: "postgresql://test:test@localhost:5432/test",
  DIRECT_URL: "postgresql://test:test@localhost:5432/test",
  SUPABASE_URL: "https://test.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "test-service-role-key",
  CLERK_SECRET_KEY: "sk_test_dummy",
  CLERK_PUBLISHABLE_KEY: "pk_test_dummy",
  CLERK_WEBHOOK_SECRET: "whsec_dummy",
  INTERNAL_CRON_SECRET: "test-internal-secret",
  NODE_ENV: "test",
};

for (const [key, value] of Object.entries(defaults)) {
  if (!process.env[key]) process.env[key] = value;
}
