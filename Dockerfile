FROM php:8.4-cli

# System deps
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git unzip curl libzip-dev libpng-dev libonig-dev libxml2-dev; \
    docker-php-ext-install pdo pdo_mysql zip fileinfo; \
    rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Node 20 for Vite build
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache layers
COPY composer.json composer.lock package.json package-lock.json ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist \
    && npm ci

# App files
COPY . .

RUN rm -f public/hot

RUN php artisan config:clear && php artisan route:clear && php artisan view:clear

# Build assets + optimize
RUN npm run build \
    && php artisan config:clear \
    && php artisan route:clear \
    && php artisan view:clear

# Railway listens on $PORT
EXPOSE 8080

CMD sh -lc "php artisan migrate --force || true; php artisan serve --host=0.0.0.0 --port=${PORT:-8080}"
