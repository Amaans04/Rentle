import type { FastifyInstance } from "fastify";
import { Webhook } from "svix";
import { OrgMemberRole } from "@prisma/client";
import { env } from "../../lib/env.js";
import { prisma } from "../../lib/prisma.js";
import { ok, fail } from "../../lib/api-response.js";

// Minimal shape of the Clerk webhook events we handle — not the full SDK type.
type ClerkWebhookEvent = {
  type: string;
  data: Record<string, unknown>;
};

/**
 * This is the ONLY place local User/Organization/OrganizationMember rows are
 * created or change existence — never invented ad hoc inside a request
 * handler from a client-supplied field (that pattern is exactly how the
 * admin-login.js account-takeover bug happened in the prior project).
 *
 * Registered as its own encapsulated plugin so the raw-string body parser
 * below (required for svix signature verification) doesn't leak into the
 * rest of the app's normal JSON parsing.
 */
export async function clerkWebhookRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.addContentTypeParser("application/json", { parseAs: "string" }, (_req, body, done) => {
    done(null, body);
  });

  fastify.post("/webhooks/clerk", async (request, reply) => {
    const svixId = request.headers["svix-id"];
    const svixTimestamp = request.headers["svix-timestamp"];
    const svixSignature = request.headers["svix-signature"];

    if (
      typeof svixId !== "string" ||
      typeof svixTimestamp !== "string" ||
      typeof svixSignature !== "string"
    ) {
      return reply.status(400).send(fail("INVALID_WEBHOOK", "Missing svix headers."));
    }

    if (!env.CLERK_WEBHOOK_SECRET) {
      return reply
        .status(503)
        .send(fail("WEBHOOK_NOT_CONFIGURED", "CLERK_WEBHOOK_SECRET is not set yet."));
    }

    let event: ClerkWebhookEvent;
    try {
      const wh = new Webhook(env.CLERK_WEBHOOK_SECRET);
      event = wh.verify(request.body as string, {
        "svix-id": svixId,
        "svix-timestamp": svixTimestamp,
        "svix-signature": svixSignature,
      }) as ClerkWebhookEvent;
    } catch {
      return reply.status(400).send(fail("INVALID_WEBHOOK", "Signature verification failed."));
    }

    await handleClerkEvent(event);
    return reply.status(200).send(ok({ received: true }));
  });
}

async function handleClerkEvent(event: ClerkWebhookEvent): Promise<void> {
  switch (event.type) {
    case "user.created":
    case "user.updated":
      await upsertUser(event.data);
      break;
    case "user.deleted":
      await softDeleteUser(event.data);
      break;
    case "organization.created":
    case "organization.updated":
      await upsertOrganization(event.data);
      break;
    case "organization.deleted":
      await softDeleteOrganization(event.data);
      break;
    case "organizationMembership.created":
    case "organizationMembership.updated":
      await upsertMembership(event.data);
      break;
    case "organizationMembership.deleted":
      await deactivateMembership(event.data);
      break;
    default:
      // Unhandled event types are ignored, not errors — Clerk sends many
      // event types we don't need (sessions, email addresses, etc).
      break;
  }
}

function primaryEmail(data: Record<string, unknown>): string | undefined {
  const addresses = data.email_addresses as Array<{ id: string; email_address: string }> | undefined;
  const primaryId = data.primary_email_address_id as string | undefined;
  return addresses?.find((a) => a.id === primaryId)?.email_address ?? addresses?.[0]?.email_address;
}

function primaryPhone(data: Record<string, unknown>): string | undefined {
  const numbers = data.phone_numbers as Array<{ id: string; phone_number: string }> | undefined;
  const primaryId = data.primary_phone_number_id as string | undefined;
  return numbers?.find((p) => p.id === primaryId)?.phone_number ?? numbers?.[0]?.phone_number;
}

async function upsertUser(data: Record<string, unknown>): Promise<void> {
  const clerkId = data.id as string;
  const email = primaryEmail(data);
  const phone = primaryPhone(data);
  const name = [data.first_name, data.last_name].filter(Boolean).join(" ") || null;
  const avatarUrl = (data.image_url as string | undefined) ?? null;

  await prisma.user.upsert({
    where: { clerkId },
    create: { clerkId, email, phone, name, avatarUrl },
    update: { email, phone, name, avatarUrl, deletedAt: null },
  });
}

async function softDeleteUser(data: Record<string, unknown>): Promise<void> {
  const clerkId = data.id as string;
  await prisma.user.updateMany({ where: { clerkId }, data: { deletedAt: new Date() } });
}

async function upsertOrganization(data: Record<string, unknown>): Promise<void> {
  const clerkOrgId = data.id as string;
  const name = data.name as string;
  const slug = (data.slug as string) ?? clerkOrgId;
  const logoUrl = (data.image_url as string | undefined) ?? null;

  await prisma.organization.upsert({
    where: { clerkOrgId },
    create: { clerkOrgId, name, slug, logoUrl },
    update: { name, slug, logoUrl, deletedAt: null },
  });
}

async function softDeleteOrganization(data: Record<string, unknown>): Promise<void> {
  const clerkOrgId = data.id as string;
  await prisma.organization.updateMany({ where: { clerkOrgId }, data: { deletedAt: new Date() } });
}

// Clerk's own org roles (org:admin / org:member) are coarse and only used to
// pick a sane DEFAULT here. Granular roles (MANAGER/RECEPTIONIST/ACCOUNTANT/
// STAFF) are business-specific and assigned via our own staff-invite API
// (Phase 1) by updating OrganizationMember.role directly — this webhook only
// keeps membership existence/isActive in sync, per the plan's explicit
// decision not to assume Clerk's role strings mirror ours.
function defaultRoleFor(clerkRole: unknown): OrgMemberRole {
  return clerkRole === "org:admin" ? OrgMemberRole.OWNER : OrgMemberRole.STAFF;
}

async function upsertMembership(data: Record<string, unknown>): Promise<void> {
  const organizationData = data.organization as Record<string, unknown>;
  const publicUserData = data.public_user_data as Record<string, unknown>;
  const clerkOrgId = organizationData.id as string;
  const clerkUserId = publicUserData.user_id as string;
  const clerkRole = data.role as string | undefined;

  const [org, user] = await Promise.all([
    prisma.organization.findUnique({ where: { clerkOrgId } }),
    prisma.user.findUnique({ where: { clerkId: clerkUserId } }),
  ]);
  // Webhook ordering lag — Clerk fires organization.created and this event
  // near-simultaneously for a brand-new org, and Svix doesn't guarantee
  // delivery order across event types, so this one can genuinely arrive
  // first. MUST throw (not return) here: the route handler has no
  // try/catch around this call, so throwing surfaces as a 500, which is
  // what makes Svix actually retry. Returning normally makes the route
  // reply 200 — Svix counts that as permanently delivered and never
  // retries, silently dropping the membership forever. This was a real bug
  // found 2026-08-10: a fresh org's OWNER membership never got created
  // because this raced organization.created and the event was swallowed.
  if (!org || !user) throw new Error(`organizationMembership webhook raced org/user creation (org=${clerkOrgId}, user=${clerkUserId}) — retry needed`);

  const existing = await prisma.organizationMember.findUnique({
    where: { organizationId_userId: { organizationId: org.id, userId: user.id } },
  });

  await prisma.organizationMember.upsert({
    where: { organizationId_userId: { organizationId: org.id, userId: user.id } },
    create: {
      organizationId: org.id,
      userId: user.id,
      role: defaultRoleFor(clerkRole),
      isActive: true,
    },
    update: {
      // Preserve a role that's already been set via our own API — only fall
      // back to the Clerk-derived default if this is genuinely new.
      role: existing?.role ?? defaultRoleFor(clerkRole),
      isActive: true,
      deletedAt: null,
    },
  });
}

async function deactivateMembership(data: Record<string, unknown>): Promise<void> {
  const organizationData = data.organization as Record<string, unknown>;
  const publicUserData = data.public_user_data as Record<string, unknown>;
  const clerkOrgId = organizationData.id as string;
  const clerkUserId = publicUserData.user_id as string;

  const [org, user] = await Promise.all([
    prisma.organization.findUnique({ where: { clerkOrgId } }),
    prisma.user.findUnique({ where: { clerkId: clerkUserId } }),
  ]);
  // Same reasoning as upsertMembership above — throw, don't return, or a
  // race swallows this event with no retry.
  if (!org || !user) throw new Error(`organizationMembership.deleted webhook raced org/user lookup (org=${clerkOrgId}, user=${clerkUserId}) — retry needed`);

  await prisma.organizationMember.updateMany({
    where: { organizationId: org.id, userId: user.id },
    data: { isActive: false, deletedAt: new Date() },
  });
}
