import { getFirebaseStorage } from '@/lib/firebase';
import type { StorageProvider, UploadUrlOptions } from '@/interfaces/storage.provider';
import { logger } from '@/lib/logger';

export class FirebaseStorageProvider implements StorageProvider {
  async getUploadUrl(options: UploadUrlOptions): Promise<{ uploadUrl: string; path: string }> {
    const storage = getFirebaseStorage();
    const bucket = storage.bucket();
    const path = `orgs/${options.organizationId}/${options.path}`;
    const file = bucket.file(path);
    const expires = Date.now() + (options.expiresInSeconds ?? 900) * 1000;

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires,
      contentType: options.contentType,
    });

    logger.info('storage.upload_url_created', {
      organizationId: options.organizationId,
      path,
    });

    return { uploadUrl, path };
  }

  async getDownloadUrl(path: string, expiresInSeconds = 900): Promise<string> {
    const storage = getFirebaseStorage();
    const file = storage.bucket().file(path);
    const [url] = await file.getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: Date.now() + expiresInSeconds * 1000,
    });
    return url;
  }

  async deleteObject(path: string): Promise<void> {
    const storage = getFirebaseStorage();
    await storage.bucket().file(path).delete({ ignoreNotFound: true });
    logger.info('storage.object_deleted', { path });
  }
}

let storageProviderInstance: FirebaseStorageProvider | null = null;

export function getStorageProvider(): FirebaseStorageProvider {
  if (!storageProviderInstance) {
    storageProviderInstance = new FirebaseStorageProvider();
  }
  return storageProviderInstance;
}
