FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

# Strip unused package managers (npm, corepack, yarn) from the runtime image
# to reduce attack surface and eliminate their bundled dependency CVEs.
RUN rm -rf \
      /usr/local/lib/node_modules/npm \
      /usr/local/lib/node_modules/corepack \
      /opt/yarn* \
      /usr/local/bin/npm \
      /usr/local/bin/npx \
      /usr/local/bin/corepack \
      /usr/local/bin/yarn \
      /usr/local/bin/yarnpkg

COPY --from=builder /app/node_modules ./node_modules
COPY package.json app.js ./

USER node
EXPOSE 8080
CMD ["node", "app.js"]
