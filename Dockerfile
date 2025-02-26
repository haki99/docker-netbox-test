# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.17

# set version label
ARG BUILD_DATE
ARG VERSION
ARG NETBOX_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="alex-phillips"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --upgrade --virtual=build-dependencies \
    build-base \
    cargo \
    jpeg-dev \
    libffi-dev \
    libxslt-dev \
    libxml2-dev \
    openssl-dev \
    postgresql-dev \
    python3-dev \
    zlib-dev && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache --upgrade \
    tiff \
    postgresql-client \
    python3 \
    uwsgi \
    uwsgi-python && \
  echo "**** install netbox ****" && \
  mkdir -p /app/netbox && \
  if [ -z ${NETBOX_RELEASE+x} ]; then \
    NETBOX_RELEASE=$(curl -sX GET "https://api.github.com/repos/netbox-community/netbox/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -o \
  /tmp/netbox.tar.gz -L \
    "https://github.com/netbox-community/netbox/archive/${NETBOX_RELEASE}.tar.gz" && \
  tar xf \
  /tmp/netbox.tar.gz -C \
    /app/netbox/ --strip-components=1 && \
    echo "**** install pip packages ****" && \
  cd /app/netbox && \
  python3 -m ensurepip --upgrade && \
  pip3 install -U --no-cache-dir \
    pip \
    wheel && \
  pip3 install --no-cache-dir --ignore-installed --find-links https://wheel-index.linuxserver.io/alpine-3.17/ -r requirements.txt && \
  echo "**** plugin installation ****" && \
  pip3 install --no-cache-dir -U pip netbox-topology-views && \
  echo "**** crond job creation ****" && \
  echo "*  *  1  *  *    /app/netbox/contrib/netbox-housekeeping.sh" >> /var/spool/cron/crontabs/root && \
  echo "/usr/bin/env python /app/netbox/netbox/manage.py housekeeping" > /app/netbox/contrib/netbox-housekeeping.sh && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    ${HOME}/.cargo \
    ${HOME}/.cache

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 8000

VOLUME /config
