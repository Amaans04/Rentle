/**
 * Wraps Supabase Storage so callers never touch the SDK directly. Postgres
 * only ever stores a storageKey reference — raw bytes never transit a
 * TypeScript handler.
 */
export interface StorageProvider {
  createSignedUploadUrl(input: {
    bucket: string;
    path: string;
    expiresInSeconds?: number;
  }): Promise<{ signedUrl: string; storageKey: string }>;
  createSignedDownloadUrl(input: { bucket: string; storageKey: string }): Promise<string>;
}
