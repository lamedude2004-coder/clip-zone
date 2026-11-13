# Deploy ClipZone on Railway

This repository now includes a Railway Docker deployment. Railway can build and run the web app, but the app also needs database, cache/queue, search, and object-storage services for its full feature set.

## 1. Connect the repository

1. Sign in to Railway and create a project from the GitHub repository `lamedude2004-coder/clip-zone`.
2. Deploy the `main` branch and leave the service root at the repository root. Railway will use `Dockerfile` and `railway.json`.
3. Add Railway services named **MySQL** and **Redis** (or adjust the variable references below to match your service names).
4. Generate a public domain for the web service.

The Railway config runs Laravel migrations before each deployment and checks the Laravel `/up` health endpoint. Nginx, PHP-FPM, and Horizon run together in the app container so queue jobs can access the same temporary upload files as the web process.

## 2. Set web service variables

Set these in the web service's Railway Variables tab. Railway reference values assume your database and Redis services are named `MySQL` and `Redis`.

```env
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:REPLACE_WITH_A_RANDOM_32_BYTE_BASE64_KEY
APP_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
LOG_CHANNEL=stderr

DB_CONNECTION=mysql
DB_HOST=${{MySQL.MYSQLHOST}}
DB_PORT=${{MySQL.MYSQLPORT}}
DB_DATABASE=${{MySQL.MYSQLDATABASE}}
DB_USERNAME=${{MySQL.MYSQLUSER}}
DB_PASSWORD=${{MySQL.MYSQLPASSWORD}}

CACHE_DRIVER=redis
LIMITER_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
REDIS_CLIENT=predis
REDIS_HOST=${{Redis.REDISHOST}}
REDIS_PORT=${{Redis.REDISPORT}}
REDIS_USERNAME=${{Redis.REDISUSER}}
REDIS_PASSWORD=${{Redis.REDISPASSWORD}}

SCOUT_DRIVER=meilisearch
MEILISEARCH_HOST=http://${{Meilisearch.RAILWAY_PRIVATE_DOMAIN}}:7700
MEILISEARCH_KEY=${{Meilisearch.MEILI_MASTER_KEY}}
```

Generate a fresh application key locally with `printf 'base64:'; openssl rand -base64 32 | tr -d '\n'; printf '\n'`, then paste the complete result into `APP_KEY`. Keep it private and do not commit it.

Before the first deployment, add a Railway service using the `getmeili/meilisearch:v1.53` image, name it `Meilisearch`, set a strong `MEILI_MASTER_KEY`, and attach a persistent volume for its data. The app's search feature is configured to use this service.

## 3. Configure required integrations

The frontend initializes Pusher Echo on page load, so configure a Pusher Channels app in the `eu` cluster before building the app. Set the server values as Railway runtime variables:

```env
PUSHER_APP_ID=your-app-id
PUSHER_APP_KEY=your-app-key
PUSHER_APP_SECRET=your-app-secret
PUSHER_HOST=api-eu.pusher.com
PUSHER_PORT=443
PUSHER_SCHEME=https
```

Set these as Railway build variables too (the Dockerfile passes them into Vite; rebuild after changing them):

```env
VITE_PUSHER_APP_KEY=your-app-key
VITE_PUSHER_APP_CLUSTER=eu
VITE_PUSHER_WEBSOCKETS_HOST=ws-eu.pusher.com
VITE_PUSHER_PORT=443
VITE_PUSHER_SCHEME=https
```

Video uploads and generated media use the S3 disk directly, so configure an S3-compatible object store (for example Cloudflare R2) before enabling uploads. Set `FILESYSTEM_DISK=s3` and the corresponding `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_BUCKET`, `AWS_ENDPOINT`, `AWS_URL`, `AWS_USE_PATH_STYLE_ENDPOINT`, and `MINIO_PUBLIC_URL` values. Use a public media URL/custom domain for `AWS_URL` and `MINIO_PUBLIC_URL` so browsers can play uploaded videos and load thumbnails. Do not rely on the container filesystem for permanent media.

Other integrations (SMTP, Stripe, Google/Facebook login, YouTube, Turnstile) are optional and need their provider credentials configured separately.

## Important

- The image includes FFmpeg and starts Horizon, so Redis must be configured for queued jobs.
- Migrations run automatically; database seeders do not. Do not run `php artisan db:seed` on a public deployment without changing the seeder first: it creates a known `admin` / `admin` account.
- Railway deployment creates the running service and its generated domain. Domain and provider credentials must be set in Railway; they are not stored in this repository.
