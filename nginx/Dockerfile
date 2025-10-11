# nginx/Dockerfile
FROM nginx:alpine

# 현재 디렉터리 기준으로 파일 복사
COPY ./nginx.conf /etc/nginx/conf.d/default.conf
COPY ./index.html /var/www/html/index.html

# 로그 디렉터리 준비 (선택)
RUN mkdir -p /var/log/nginx && \
    chmod -R 755 /var/log/nginx /var/www/html

EXPOSE 80

# nginx 기본 실행 명령 유지
# CMD ["nginx", "-g", "daemon off;"]
