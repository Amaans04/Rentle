import { NextRequest } from 'next/server';
import { env } from '@/lib/env';

export function corsHeaders(request: NextRequest): Record<string, string> {
  const origin = request.headers.get('origin') || '';
  const allowed = env.allowedOrigins.includes(origin) ? origin : env.allowedOrigins[0];

  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Credentials': 'true',
  };
}

export function handleCors(request: NextRequest): Response | null {
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(request),
    });
  }
  return null;
}
