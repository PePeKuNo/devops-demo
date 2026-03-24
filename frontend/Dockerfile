# Etap 1. Buduję produkcyjną wersję frontendu
# Node.js jest mi tu potrzebny tylko do instalacji zależności i buildu
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Po buildzie katalog /app/build zawiera gotowe pliki statyczne

# Etap 2. Serwuję gotowe pliki przez Nginx
# W finalnym obrazie zostawiam już tylko Nginx
FROM nginx:alpine

# Kopiuję zbudowany frontend do katalogu publicznego Nginxa
COPY --from=build /app/build /usr/share/nginx/html

# Podmieniam domyślną konfigurację Nginxa na własną
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Trzymam Nginxa na pierwszym planie, żeby kontener się nie kończył
CMD ["nginx", "-g", "daemon off;"]
