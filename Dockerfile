FROM php:8.4-apache

# 1. Install System Dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y git unzip libzip-dev libpng-dev libonig-dev libxml2-dev curl; \
    docker-php-ext-install pdo pdo_mysql zip fileinfo; \
    a2enmod rewrite; \
    rm -rf /var/lib/apt/lists/*

# 2. Set Apache Root
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
 && sed -ri 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# 3. Install Tooling (Composer & Node)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# --- THE CACHE TRICK ---

# 4. Copy ONLY dependency files first
COPY composer.json composer.lock package.json package-lock.json ./

# 5. Install dependencies (This layer stays cached unless json/lock files change)
RUN composer install --no-dev --no-scripts --no-autoloader \
    && npm ci

# 6. Copy the rest of the application
COPY . .

# 7. Finalize build
RUN composer dump-autoload --optimize \
    && npm run build \
    && chown -R www-data:www-data storage bootstrap/cache

EXPOSE 80
CMD ["apache2-foreground"]