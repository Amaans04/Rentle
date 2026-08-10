import type { Prisma, Property } from "@prisma/client";

type AddressShape = { city?: unknown; state?: unknown };

/**
 * Keeps the public, non-RLS `property_listings` directory in sync with a
 * Property write. Called from inside the same withOrgContext transaction as
 * every properties.ts mutation, so a listing can never exist without a real,
 * currently-discoverable Property behind it. Only name/city/state are ever
 * copied — see the model comment in schema.prisma for why nothing else
 * (address line, phone, amenities, photos) belongs here.
 */
export async function syncPropertyListing(tx: Prisma.TransactionClient, property: Property): Promise<void> {
  if (!property.discoverable || property.deletedAt) {
    await tx.propertyListing.deleteMany({ where: { propertyId: property.id } });
    return;
  }

  const address = property.address as AddressShape;
  const city = typeof address.city === "string" ? address.city : "";
  const state = typeof address.state === "string" ? address.state : "";

  await tx.propertyListing.upsert({
    where: { propertyId: property.id },
    create: { organizationId: property.organizationId, propertyId: property.id, name: property.name, city, state },
    update: { name: property.name, city, state },
  });
}
