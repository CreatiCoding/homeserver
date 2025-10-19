FROM node:22-alpine

ARG PORT

ENV PORT=${PORT}

WORKDIR /app

COPY . .

RUN corepack enable

WORKDIR /app/servers/homeserver-controller

RUN yarn workspaces focus --production

CMD ["yarn", "start"]
