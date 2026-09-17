FROM php:8.4-fpm-bookworm

WORKDIR /app

# System packages
RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    git \
    unzip \
    zip \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    default-mysql-client \
    gettext-base \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        bcmath \
        exif \
        gd \
        intl \
        mbstring \
        opcache \
        pdo \
        pdo_mysql \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Node.js 24
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && npm --version \
    && node --version \
    && rm -rf /var/lib/apt/lists/*

# Copy PHP dependency files first for Docker layer caching
COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts

# Copy Node dependency files
COPY package.json package-lock.json ./

RUN npm ci

# Copy application
COPY . .

# Build frontend assets
RUN npm run build

# Laravel runtime directories
RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    && chown -R www-data:www-data \
        storage \
        bootstrap/cache

# Nginx
COPY docker/nginx.conf /etc/nginx/nginx.conf

# PHP production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Remove default nginx site
RUN rm -f /etc/nginx/sites-enabled/default \
    /etc/nginx/conf.d/default.conf

EXPOSE 10000

CMD ["sh", "-c", "php artisan storage:link --force || true; php-fpm -D; nginx -g 'daemon off;'"]