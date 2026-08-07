import { PrismaClient } from "@prisma/client";
import { env } from "./env.js";

// Caps how many real connections THIS client opens against Supabase's
// pooler. Kept small deliberately — the free-tier pooler has a limited
// number of slots, and every extra PrismaClient instance (the app itself,
// plus one per test file under vitest, since each file gets its own module
// registry) adds its own pool on top. A CI run once hung indefinitely with
// the unbounded default rather than erroring cleanly — see docs/PROGRESS.md.
const datasourceUrl = `${env.DATABASE_URL}${env.DATABASE_URL.includes("?") ? "&" : "?"}connection_limit=3`;

// Single PrismaClient instance for the whole process — Fastify's request
// lifecycle reuses this via req.server.prisma, never `new PrismaClient()`
// inside a handler.
export const prisma = new PrismaClient({
  log: env.NODE_ENV === "development" ? ["warn", "error"] : ["error"],
  datasourceUrl,
});
