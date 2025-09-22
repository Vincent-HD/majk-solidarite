ARG PHP_VERSION=8.3
ARG WORDPRESS_VERSION=latest
FROM wordpress:$WORDPRESS_VERSION AS wp
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
    imagick \
    opcache

# Copy Wordpress files from official wp image to follow their requirements, used when wordpress is not installed, it will setup a wp config for docker based on ENV variables
COPY --from=wp /usr/src/wordpress /usr/src/wordpress
COPY --from=wp /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d/
COPY --from=wp /usr/local/bin/docker-entrypoint.sh /usr/local/bin/

# See https://github.com/StephenMiracle/frankenwp/blob/e05bcc3d951dc57636c87befa63357ec1350006d/Dockerfile#L119
RUN sed -i \
    -e 's/\[ "$1" = '\''php-fpm'\'' \]/\[\[ "$1" == frankenphp* \]\]/g' \
    -e 's/php-fpm/frankenphp/g' \
    /usr/local/bin/docker-entrypoint.sh

RUN { \
    # https://www.php.net/manual/en/errorfunc.constants.php
    # https://github.com/docker-library/wordpress/issues/420#issuecomment-517839670
    echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
    echo 'display_errors = Off'; \
    echo 'display_startup_errors = Off'; \
    echo 'log_errors = On'; \
    echo 'error_log = /dev/stderr'; \
    echo 'log_errors_max_len = 1024'; \
    echo 'ignore_repeated_errors = On'; \
    echo 'ignore_repeated_source = Off'; \
    echo 'html_errors = Off'; \
    } > /usr/local/etc/php/conf.d/error-logging.ini

COPY --chown=$UID:$GID ./config/php/ $PHP_INI_DIR/conf.d/ 

RUN \
    useradd ${USER} -u ${UID} -g ${GID}; \
    # Add additional capability to bind to port 80 and 443
    setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp; \
    # Give write access to /config/caddy and /data/caddy
    chown -R ${UID}:${GID} /config/caddy /data/caddy /usr/src/wordpress /var/www/html

USER ${UID}:${GID}

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/config/caddy/Caddyfile"]