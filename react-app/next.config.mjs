// next.config.mjs
// Next.js 14 does not support next.config.ts — use .mjs (ESM) or .js instead.
// output: "standalone" is REQUIRED for SPCS: produces a self-contained
// server.js that the Docker container runs directly.

/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
};

export default nextConfig;
