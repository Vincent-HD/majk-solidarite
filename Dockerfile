ARG PHP_VERSION=8.3
FROM dunglas/frankenphp:php${PHP_VERSION}

ARG USER=www-data
ARG UID=1000
ARG GID=1000

RUN cp $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini

# Create tools directory and setup tools
RUN mkdir -p /var/www/tools
COPY --chown=$UID:$GID ./php/tools/ /var/www/tools/
# Opcache Dashboard
RUN curl -o /var/www/tools/opcache.php https://raw.githubusercontent.com/amnuts/opcache-gui/refs/heads/master/index.php

# install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN install-php-extensions \
    bcmath \
    exif \
    gd \
    intl \
    mysqli \
    zip \
    # See https://github.com/Imagick/imagick/issues/640#issuecomment-2077206945
    imagick/imagick@master \
    opcache

RUN \
    useradd ${USER} -u ${UID} -g ${GID}; \
    # Add additional capability to bind to port 80 and 443
    setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp; \
    # Give write access to /config/caddy and /data/caddy
    chown -R ${UID}:${GID} /config/caddy /data/caddy

USER ${UID}:${GID}

WORKDIR /var/www/html

CMD ["frankenphp", "run", "--config", "/config/caddy/Caddyfile"]