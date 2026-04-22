FROM nginx:1.27-alpine

ARG BUILD_DATE
ARG VERSION

LABEL org.opencontainers.image.title="product-dashboard-proxy" \
      org.opencontainers.image.description="Nginx reverse proxy for backend_1 and backend_2" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.version=$VERSION

RUN apk add --no-cache curl iputils

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://127.0.0.1/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
