ARG PHP_VERSION=8.2-fpm

FROM php:${PHP_VERSION}-alpine3.18

ENV PHP_EXTRA_CONFIGURE_ARGS \
    --enable-fpm \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
    --enable-intl \
    --enable-opcache \
    --enable-zip

RUN apk --update --no-cache add \
    bash \
    fcgi \
    freetype-dev \
    icu-dev \
    icu-libs \
    icu-data-full \
    jq \
    libjpeg-turbo-dev \
    libxslt-dev \
    libzip-dev \
    procps \
    rsync \
    tini \
    && apk --update --no-cache --virtual build-deps add \
    curl-dev \
    g++ \
    libpng-dev \
    libssh2-dev \
    libxml2-dev \
    oniguruma-dev \
    shadow \
    zlib-dev

# Issue with linux sockets for php image 8.2-alpine https://github.com/php/php-src/issues/8681
RUN apk add --no-cache linux-headers

# https://github.com/spatie/pdf-to-image
# https://github.com/spatie/pdf-to-text
RUN apk --update --no-cache add \
    icu-data-full \
    imagemagick \
    imagemagick-dev \
    poppler-utils

RUN docker-php-ext-configure gd --with-jpeg=/usr/include/ --with-freetype=/usr/include/

RUN docker-php-ext-install \
    bcmath \
    gd \
    intl \
    opcache \
    pdo_mysql \
    soap \
    sockets \
    xsl \
    zip

# Install Redis client and apcu.
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl channel-update pecl.php.net \
    && pecl install --nocompress redis && docker-php-ext-enable redis \
    && pecl install apcu && docker-php-ext-enable apcu

# Install imagick
RUN pecl install imagick-3.7.0
RUN docker-php-ext-enable imagick

# Install Composer.
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN usermod -u 1000 www-data \
    && usermod -G www-data www-data

RUN apk del build-deps

# Processor config
RUN apk add --update busybox-suid
RUN mkdir -p /etc/periodic/magento && \
    chown -R www-data:www-data /etc/periodic/magento

# Install xdebug.
RUN pecl install xdebug-3.2.1

USER www-data

RUN echo "* * * * * /usr/local/bin/magento-reindex 2>&1" > /etc/periodic/magento/reindex
RUN echo "* * * * * /usr/local/bin/php /var/www/html/bin/magento cron:run 2>&1 | grep -v 'Ran jobs by schedule'" > /etc/periodic/magento/cron
RUN crontab /etc/periodic/magento/cron
