FROM node:20-alpine AS base
WORKDIR /app

RUN apk add --no-cache curl

COPY package.json .
RUN npm install --omit=dev

COPY docker-entrypoint.sh ./docker-entrypoint.sh
COPY src/ src/
RUN chmod +x docker-entrypoint.sh

EXPOSE 4000
ENV NODE_ENV=production
ENV PORT=4000

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["node", "src/server.js"]
