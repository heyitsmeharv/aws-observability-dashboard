FROM node:20-alpine AS base
WORKDIR /app

COPY package.json .
RUN npm install --omit=dev

COPY src/ src/

EXPOSE 4000
ENV NODE_ENV=production
ENV PORT=4000

CMD ["node", "src/server.js"]
