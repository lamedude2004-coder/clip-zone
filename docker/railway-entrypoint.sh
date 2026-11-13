#!/bin/sh
set -eu

PORT="${PORT:-8080}"
export PORT

envsubst '${PORT}' < /etc/nginx/templates/app.conf.template > /etc/nginx/http.d/app.conf

exec /usr/bin/supervisord -c /etc/supervisord.conf
