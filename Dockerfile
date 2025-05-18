# syntax=docker/dockerfile:1
FROM php:8.2-cli

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set workdir
WORKDIR /app

# Copy all files
COPY . /app

# Install PHP dependencies
RUN composer install

CMD ["php", "-v"]
