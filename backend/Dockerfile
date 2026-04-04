# syntax=docker/dockerfile:1.7

FROM node:20-alpine AS deps
ARG NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY app.js server.js ./

FROM deps AS test
ENV NODE_ENV=test
RUN npm ci
COPY tests ./tests
RUN npm test

FROM node:20-alpine AS production
ARG BUILD_DATE
ARG VERSION
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV
WORKDIR /app
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.title="demo-backend"
RUN --mount=from=test,source=/app,target=/test,ro test -f /test/package.json
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package*.json ./
COPY --from=deps /app/app.js ./app.js
COPY --from=deps /app/server.js ./server.js
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health > /dev/null || exit 1
CMD ["node", "server.js"]
