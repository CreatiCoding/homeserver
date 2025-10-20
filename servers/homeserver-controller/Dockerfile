FROM node:22-alpine

ARG PORT

ENV PORT=${PORT}

ENV KEY_PATH=/app/ci_id_rsa

WORKDIR /app

RUN apk add bash
RUN apk add openssh

COPY . .

COPY ./ci_id_rsa /app/ci_id_rsa

RUN corepack enable

WORKDIR /app/servers/homeserver-controller

RUN yarn workspaces focus --production

CMD ["yarn", "start"]
