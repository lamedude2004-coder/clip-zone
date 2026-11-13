FROM oven/bun:1.3.14-alpine AS assets

WORKDIR /app
RUN apk add --no-cache git

ARG VITE_PUSHER_APP_KEY=
ARG VITE_PUSHER_APP_CLUSTER=eu
ARG VITE_PUSHER_WEBSOCKETS_HOST=ws-eu.pusher.com
ARG VITE_PUSHER_PORT=443
ARG VITE_PUSHER_SCHEME=https
ENV VITE_PUSHER_APP_KEY=${VITE_PUSHER_APP_KEY} \
    VITE_PUSHER_APP_CLUSTER=${VITE_PUSHER_APP_CLUSTER} \
    VITE_PUSHER_WEBSOCKETS_HOST=${VITE_PUSHER_WEBSOCKETS_HOST} \
    VITE_PUSHER_PORT=${VITE_PUSHER_PORT} \
    VITE_PUSHER_SCHEME=${VITE_PUSHER_SCHEME}

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
RUN test -n "$VITE_PUSHER_APP_KEY" || (echo "Set VITE_PUSHER_APP_KEY as a Railway build variable before deploying." >&2; exit 1)
RUN bun run build

FROM php:8.3.36-fpm-alpine AS app

RUN apk add --no-cache bash ffmpeg gettext-envsubst nginx supervisor \
    && mkdir -p /run/nginx /var/log/supervisor

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/install-php-extensions
RUN chmod +x /usr/local/bin/install-php-extensions \
    && install-php-extensions intl pdo_mysql pcntl bcmath gd zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .
COPY --from=assets /app/public/build ./public/build
COPY docker/railway-nginx.conf.template /etc/nginx/templates/app.conf.template
COPY docker/railway-supervisord.conf /etc/supervisord.conf
COPY docker/railway-entrypoint.sh /usr/local/bin/railway-entrypoint
COPY docker/php/php.ini /usr/local/etc/php/conf.d/zz-app.ini

RUN mkdir -p storage/app/private/videos storage/app/private/spams storage/app/private/thumbnails \
        storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-progress \
    && rm -f /etc/nginx/http.d/default.conf \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod +x /usr/local/bin/railway-entrypoint

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-entrypoint"]
