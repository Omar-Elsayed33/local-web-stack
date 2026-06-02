FROM php:8.4-fpm

# System packages and build dependencies for the PHP extensions below.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        unzip \
        zip \
        libzip-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libonig-dev \
        libicu-dev \
        msmtp \
        msmtp-mta \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Configure and install common PHP extensions.
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pdo \
        pdo_mysql \
        mysqli \
        mbstring \
        zip \
        gd \
        intl \
        bcmath \
        opcache \
        exif \
        pcntl

# Composer (copied from the official image).
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Route PHP's mail() through msmtp -> Mailpit SMTP (mailpit:1025).
# This lets legacy mail() and any app using sendmail deliver to Mailpit.
RUN printf '%s\n' \
        'defaults' \
        'auth           off' \
        'tls            off' \
        'host           mailpit' \
        'port           1025' \
        'from           noreply@local.local' \
        'logfile        /var/log/msmtp.log' \
    > /etc/msmtprc \
    && touch /var/log/msmtp.log \
    && chown www-data:www-data /var/log/msmtp.log

# Point PHP's sendmail_path at msmtp so mail() reaches Mailpit.
RUN printf '%s\n' \
        'sendmail_path = "/usr/bin/msmtp -t"' \
    > /usr/local/etc/php/conf.d/mailpit.ini

WORKDIR /var/www
