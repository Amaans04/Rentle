import { NextRequest } from 'next/server';
import { successResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwnerOrManager, requireTenant } from '@/middleware/auth';
import { requireString, ValidationError } from '@/lib/validators';
import { getStorageProvider } from '@/providers/firebase-storage.provider';

const ALLOWED_DOCUMENT_TYPES = [
  'aadhaar',
  'pan',
  'passport',
  'driving_license',
  'police_verification',
  'rental_agreement',
  'photo',
  'other',
] as const;

const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
];

function sanitizeFileName(name: string): string {
  return name.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 120);
}

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

/** Owner: upload URL for property documents */
export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const body = await parseBody<Record<string, unknown>>(request);

    const fileName = sanitizeFileName(requireString(body.fileName, 'fileName'));
    const contentType = requireString(body.contentType, 'contentType');
    const documentType = requireString(body.documentType, 'documentType');

    if (!ALLOWED_MIME_TYPES.includes(contentType)) {
      throw new ValidationError('Unsupported file type');
    }
    if (!ALLOWED_DOCUMENT_TYPES.includes(documentType as (typeof ALLOWED_DOCUMENT_TYPES)[number])) {
      throw new ValidationError('Invalid document type');
    }

    let organizationId: string;
    let path: string;

    if (user.role === 'tenant') {
      const pgId = requireTenant(user);
      organizationId = pgId;
      path = `tenants/${user.uid}/documents/${documentType}/${Date.now()}-${fileName}`;
    } else {
      organizationId = requireOwnerOrManager(user);
      const tenantId = body.tenantId ? String(body.tenantId) : 'property';
      path = `tenants/${tenantId}/documents/${documentType}/${Date.now()}-${fileName}`;
    }

    const storage = getStorageProvider();
    const result = await storage.getUploadUrl({
      organizationId,
      path,
      contentType,
    });

    const response = successResponse({
      uploadUrl: result.uploadUrl,
      storagePath: result.path,
      documentType,
      contentType,
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
