import { createClient } from "@supabase/supabase-js";
import { env } from "./env.js";
import type { StorageProvider } from "../interfaces/storage.provider.js";

const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

export const supabaseStorage: StorageProvider = {
  async createSignedUploadUrl({ bucket, path, expiresInSeconds = 300 }) {
    const { data, error } = await supabase.storage.from(bucket).createSignedUploadUrl(path);
    if (error || !data) throw new Error(`Failed to create signed upload URL: ${error?.message}`);
    void expiresInSeconds; // Supabase signed-upload URLs use a fixed short expiry server-side
    return { signedUrl: data.signedUrl, storageKey: data.path };
  },

  async createSignedDownloadUrl({ bucket, storageKey }) {
    const { data, error } = await supabase.storage
      .from(bucket)
      .createSignedUrl(storageKey, 300);
    if (error || !data) throw new Error(`Failed to create signed download URL: ${error?.message}`);
    return data.signedUrl;
  },
};
