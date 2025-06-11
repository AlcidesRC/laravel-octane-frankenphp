# syntax=docker/dockerfile:1

#----------------------------------------------------------
# STAGE: BASE-IMAGE
#----------------------------------------------------------

FROM dunglas/frankenphp:php8.4.8-alpine AS base-image

#----------------------------------------------------------
# STAGE: COMMON
#----------------------------------------------------------

FROM base-image AS common

# Add OS dependencies
RUN apk update && apk add --no-cache \
        libzip \
# Add PHP extensions
    && install-php-extensions \
    	zip \
        opcache \
        pcntl

COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

WORKDIR /app

#----------------------------------------------------------
# STAGE: BUILD-DEVELOPMENT
#----------------------------------------------------------

FROM common AS build-development

ENV ENV=DEVELOPMENT

RUN apk update && apk add --no-cache \
        bash

COPY --from=composer /usr/bin/composer /usr/bin/composer

ENTRYPOINT ["php", "artisan", "octane:frankenphp", "--workers=24", "--max-requests=2048"]

#----------------------------------------------------------
# STAGE: OPTIMIZE-PHP-DEPENDENCIES
#----------------------------------------------------------

FROM composer AS optimize-php-dependencies

# First copy Composer files
COPY src/composer.json /app/
COPY src/composer.lock /app/

# Docker will cache this step and reuse it if no any change has being done on previuos step
RUN composer install \
    --ignore-platform-reqs \
    --no-ansi \
    --no-autoloader \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --no-dev

# Ensure to copy __ONLY__ the PHP application folder(s)
# Ensure to omit the `./src/vendor` folder and avoid to install development dependencies into the optimized folder
COPY src/public /app
COPY src/private /app

# Recompile application cache
RUN composer dump-autoload \
    --optimize \
    --classmap-authoritative

#----------------------------------------------------------
# STAGE: BUILD-PRODUCTION
#----------------------------------------------------------

FROM common AS build-production

ENV ENV=PRODUCTION

COPY --from=optimize-php-dependencies /app /app
