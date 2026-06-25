/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ['firebase-admin', 'jwks-rsa', 'jose'],
  },
};

export default nextConfig;
