import { PrismaClient } from "@prisma/client";

// Single PrismaClient instance for the whole process — Fastify's request
// lifecycle reuses this via req.server.prisma, never `new PrismaClient()`
// inside a handler.
export const prisma = new PrismaClient({
  log: process.env.NODE_ENV === "development" ? ["warn", "error"] : ["error"],
});
