export interface UploadUrlOptions {
  organizationId: string;
  path: string;
  contentType: string;
  expiresInSeconds?: number;
}

export interface StorageObject {
  path: string;
  contentType: string;
  sizeBytes: number;
}

/**
 * Abstraction over object storage (Firebase Storage today, Supabase later).
 */
export interface StorageProvider {
  getUploadUrl(options: UploadUrlOptions): Promise<{ uploadUrl: string; path: string }>;
  getDownloadUrl(path: string, expiresInSeconds?: number): Promise<string>;
  deleteObject(path: string): Promise<void>;
}
