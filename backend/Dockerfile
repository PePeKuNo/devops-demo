# Krok 1. Używam lekkiego oficjalnego obrazu Node.js na Alpine
FROM node:18-alpine

# Krok 2. Ustawiam katalog roboczy /app wewnątrz kontenera
WORKDIR /app

# Krok 3. Najpierw kopiuję pliki z zależnościami
COPY package*.json ./

# Krok 4. Instaluję zależności backendu
RUN npm install

# Krok 5. Potem kopiuję resztę kodu źródłowego
COPY . .

# Krok 6. Informuję, że aplikacja działa na porcie 3000
EXPOSE 3000

# Krok 7. Uruchamiam serwer po starcie kontenera
CMD ["node", "server.js"]
