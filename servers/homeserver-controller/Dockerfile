FROM node:22-alpine

ARG PORT

ENV PORT=${PORT}

WORKDIR /app

RUN apk add bash

COPY . .

RUN cp ~/.ssh/ci_id_rsa ~/.ssh/ci_id_rsa

RUN corepack enable

WORKDIR /app/servers/homeserver-controller

RUN yarn workspaces focus --production

CMD ["yarn", "start"]
