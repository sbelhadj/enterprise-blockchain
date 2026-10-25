# The aircraft parts chaincode as a service (Lab 3). Build stage compiles TypeScript;
# the runtime stage keeps only production dependencies and runs as the unprivileged node user.
FROM node:22.22.0-alpine AS build
WORKDIR /usr/src/app
COPY package.json package-lock.json tsconfig.json ./
RUN npm ci
COPY src ./src
RUN npm run build

FROM node:22.22.0-alpine
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /usr/src/app/dist ./dist
USER node
CMD ["npm", "run", "start:server"]
