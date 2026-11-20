
FROM node:20-alpine

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install --omit=dev --no-audit --no-fund --fetch-retries=2 --fetch-timeout=30000

COPY . .

ENV PORT=8080

EXPOSE 8080

CMD ["node", "server.js"]
