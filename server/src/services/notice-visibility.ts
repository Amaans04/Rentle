import type { Prisma } from "@prisma/client";

/**
 * Builds the WHERE clause for "notices visible to a tenant at this
 * propertyId/floorId/roomId, right now" — ALL_TENANTS and PROPERTY notices
 * are always visible to anyone in the property; FLOOR/ROOM notices are only
 * visible to tenants whose bed is actually on that floor/in that room
 * (matched via audienceFilter's JSON path, not just the audience enum
 * value alone). Also excludes anything not yet published or already
 * expired.
 */
export function visibleNoticeWhere(params: {
  organizationId: string;
  propertyId: string;
  floorId: string;
  roomId: string;
  now: Date;
}): Prisma.NoticeWhereInput {
  return {
    organizationId: params.organizationId,
    propertyId: params.propertyId,
    OR: [
      { audience: "ALL_TENANTS" },
      { audience: "PROPERTY" },
      { audience: "FLOOR", audienceFilter: { path: ["floorId"], equals: params.floorId } },
      { audience: "ROOM", audienceFilter: { path: ["roomId"], equals: params.roomId } },
    ],
    AND: [
      { OR: [{ publishAt: null }, { publishAt: { lte: params.now } }] },
      { OR: [{ expiresAt: null }, { expiresAt: { gt: params.now } }] },
    ],
  };
}
