# Multi-stage Dockerfile for WKS Dashboard on SPCS
#
# REQUIRED: output: "standalone" in next.config.mjs
# REQUIRED: ENV HOSTNAME="0.0.0.0" in runner stage
#
# LOCKFILE NOTE:
#   Run `npm install` in the react-app directory once to generate
#   package-lock.json, then commit it. After that, change RUN npm install
#   to RUN npm ci so Docker uses the pinned lockfile. Without a committed
#   lockfile, dependency versions are re-resolved on every image build.

FROM node:18-alpine AS base

# ── Dependencies ────────────────────────────────────────────────────────────
FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
# Use npm ci when package-lock.json is committed; falls back to npm install
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# ── Build ───────────────────────────────────────────────────────────────────
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ── Runner ──────────────────────────────────────────────────────────────────
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
# REQUIRED: bind to 0.0.0.0 so SPCS readiness probe can reach the server
ENV HOSTNAME="0.0.0.0"
ENV PORT=3000

RUN addgroup --system --gid 1001 nodejs
RUN adduser  --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
