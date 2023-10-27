# syntax=docker/dockerfile:1.2

ARG BASE_IMAGE=debian:bookworm-slim
# ARG BASE_IMAGE=ubuntu:jammy

FROM ${BASE_IMAGE} AS build-scripts
COPY ./build-scripts ./build-scripts

# ============================ INSTALL BASIC SERVICES ============================
FROM ${BASE_IMAGE} AS base
ARG TARGETPLATFORM

# Install supervisor, postfix
# Install postfix first to get the first account (101)
# Install opendkim second to get the second account (102)
#           --mount=type=cache,target=/var/cache/apk,sharing=locked,id=var-cache-apk-$TARGETPLATFORM \
#           --mount=type=cache,target=/etc/apk/cache,sharing=locked,id=etc-apk-cache-$TARGETPLATFORM \
RUN        --mount=type=cache,target=/var/cache/apt,sharing=locked,id=var-cache-apt-$TARGETPLATFORM \
           --mount=type=cache,target=/var/lib/apt,sharing=locked,id=var-lib-apt-$TARGETPLATFORM \
           --mount=type=tmpfs,target=/var/cache/apk \
           --mount=type=tmpfs,target=/tmp \
           --mount=type=bind,from=build-scripts,source=/build-scripts,target=/build-scripts \
           sh /build-scripts/postfix-install.sh

# ============================ BUILD SASL XOAUTH2 ============================
FROM base AS sasl

ARG TARGETPLATFORM
ARG SASL_XOAUTH2_REPO_URL=https://github.com/tarickb/sasl-xoauth2.git
ARG SASL_XOAUTH2_GIT_REF=release-0.24

#           --mount=type=cache,target=/var/cache/apk,sharing=locked,id=var-cache-apk-$TARGETPLATFORM \
#           --mount=type=cache,target=/etc/apk/cache,sharing=locked,id=etc-apk-cache-$TARGETPLATFORM \
RUN        --mount=type=cache,target=/var/cache/apt,sharing=locked,id=var-cache-apt-$TARGETPLATFORM \
           --mount=type=cache,target=/var/lib/apt,sharing=locked,id=var-lib-apt-$TARGETPLATFORM \
           --mount=type=tmpfs,target=/etc/apk/cache \
           --mount=type=tmpfs,target=/var/cache/apk \
           --mount=type=tmpfs,target=/tmp \
           --mount=type=tmpfs,target=/sasl-xoauth2 \
           --mount=type=bind,from=build-scripts,source=/build-scripts,target=/build-scripts \
           sh /build-scripts/sasl-build.sh

# ============================ Prepare main image ============================
FROM sasl
LABEL maintainer="Bojan Cekrlic - https://github.com/bokysan/docker-postfix/"

# Set up configuration
COPY       /configs/supervisord.conf     /etc/supervisord.conf
COPY       /configs/rsyslog*.conf        /etc/
COPY       /configs/opendkim.conf        /etc/opendkim/opendkim.conf
COPY       /configs/smtp_header_checks   /etc/postfix/smtp_header_checks
COPY       /configs/master.cf            /etc/postfix/master.cf
COPY       /scripts/*                    /scripts/

RUN        chmod +x /scripts/*

# Set up volumes
VOLUME     [ "/var/spool/postfix", "/etc/postfix", "/etc/opendkim/keys" ]

# Run supervisord
USER       root
WORKDIR    /tmp

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD printf "EHLO healthcheck\n" | nc 127.0.0.1 587 | grep -qE "^220.*ESMTP Postfix"

EXPOSE     587
CMD        [ "/bin/sh", "-c", "/scripts/run.sh" ]
