import { z } from "zod";
import { ValidationError } from "./http-errors.js";

export const idParamSchema = z.object({ id: z.string().min(1) });
export const orgIdParamSchema = z.object({ orgId: z.string().min(1) });

export const addressSchema = z.object({
  line1: z.string().min(1),
  line2: z.string().optional(),
  city: z.string().min(1),
  state: z.string().min(1),
  pincode: z.string().min(1),
  lat: z.number().optional(),
  lng: z.number().optional(),
});

export const paginationSchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

/** Parses `schema` against `data`; on failure throws a ValidationError the global handler renders as 400. */
export function parseOrThrow<T extends z.ZodTypeAny>(schema: T, data: unknown): z.infer<T> {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw new ValidationError(result.error.flatten());
  }
  return result.data;
}
