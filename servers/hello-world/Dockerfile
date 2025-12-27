# syntax=docker/dockerfile:1

FROM oven/bun:1

WORKDIR /app

# 의존성 설치 (캐시 최적화)
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

# 소스 코드 복사
COPY src ./src

ENV NODE_ENV=production
EXPOSE 3000

CMD ["bun", "run", "src/index.ts"]
