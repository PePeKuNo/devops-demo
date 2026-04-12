FROM node:20-alpine AS deps
ARG NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:20-alpine AS build
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine AS production
ARG BUILD_DATE
ARG VERSION
ARG NODE_ENV=production
ENV NODE_ENV=$NODE_ENV
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.title="demo-frontend"
USER root
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN mkdir -p /var/cache/nginx && \
    chown -R 101:0 /usr/share/nginx/html /etc/nginx/conf.d /var/cache/nginx
USER nginx
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz > /dev/null || exit 1
CMD ["nginx", "-g", "daemon off;"]
