FROM php:8.4-apache

# Railway uses 8080 by default
ENV PORT=8080
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git unzip curl libzip-dev libpng-dev libonig-dev libxml2-dev; \
    docker-php-ext-install pdo pdo_mysql zip fileinfo; \
    a2enmod rewrite; \
    \
    # ✅ HARD disable other MPMs, enable ONLY prefork
    a2dismod mpm_event mpm_worker || true; \
    a2enmod mpm_prefork; \
    \
    # ✅ Force Apache to listen on PORT (8080)
    sed -ri "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf; \
    sed -ri "s/<VirtualHost \\*:80>/<VirtualHost \\*:${PORT}>/" /etc/apache2/sites-available/000-default.conf; \
    \
    # ✅ Serve Laravel /public
    sed -ri "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/*.conf; \
    sed -ri "s!/var/www/!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf; \
    \
    # ✅ Verify only ONE MPM is enabled (this should show only prefork)
    ls -1 /etc/apache2/mods-enabled | grep mpm; \
    \
    rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Node for Vite build
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Cache-friendly dependency layers
COPY composer.json composer.lock package.json package-lock.json ./
RUN composer install --no-dev --no-scripts --no-autoloader \
    && npm ci

COPY . .

RUN composer dump-autoload --optimize \
    && npm run build \
    && chown -R www-data:www-data storage bootstrap/cache

EXPOSE 8080
CMD ["apache2-foreground"]
