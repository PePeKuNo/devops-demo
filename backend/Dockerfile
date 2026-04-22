# syntax=docker/dockerfile:1.7

FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM node:20-alpine AS deps-dev
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM deps-dev AS test
WORKDIR /app
COPY . .
RUN npm test

FROM node:20-alpine AS production
ARG BUILD_DATE
ARG VERSION=v2
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV
WORKDIR /app
LABEL org.opencontainers.image.title="product-dashboard-backend" \
      org.opencontainers.image.description="Backend API for Product Dashboard with PostgreSQL and Redis" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.licenses="MIT"
RUN apk add --no-cache curl iputils && \
    mkdir -p /app && \
    chown -R node:node /app
COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY app.js cache.js db.js server.js worker.js ./
RUN --mount=from=test,source=/app,target=/test,ro test -f /test/package.json
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD sh -c 'curl -f http://127.0.0.1:${PORT:-3000}/health || exit 1'
CMD ["node", "server.js"]
