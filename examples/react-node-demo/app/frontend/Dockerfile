# Stage 1: build the static assets
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json .
RUN npm install

COPY index.html .
COPY vite.config.js .
COPY src/ src/

ARG VITE_API_URL=/api
ENV VITE_API_URL=$VITE_API_URL

RUN npm run build

# Stage 2: serve with a minimal static server
FROM node:20-alpine
WORKDIR /app

RUN npm install -g serve

COPY --from=builder /app/dist ./dist

EXPOSE 3000
CMD ["serve", "-s", "dist", "-l", "3000"]
