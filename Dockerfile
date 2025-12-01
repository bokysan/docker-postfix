# syntax=docker/dockerfile:1.6

# Note:
# The BASE_IMAGE can be changed for this docker image. In fact, it will be. Check .github/workflows/master.yml.
# This image is automatically built with Debian, Ubuntu and Alpine as underlying systems. Each of these has its
# own advantages and shortcomings. In essence:
#
# - use Alpine if you're strapped for space. But beware it uses MUSL LIBC, so unicode support might be an issue.
# - use Debian if you're interested in the greatest cross-platform compatibility. It is larger than Alpine, though.
# - use Ubuntu if, well, Ubuntu is your thing and you're used to the buntu ecosystem.
ARG BASE_IMAGE=debian:bookworm-slim

FROM ${BASE_IMAGE} AS build-scripts
COPY ./build-scripts ./build-scripts

# ============================ INSTALL BASIC SERVICES ============================
FROM ${BASE_IMAGE} AS base
ARG TARGETPLATFORM

# Install supervisor, postfix
# Install postfix first to get the first account (101)
# Install opendkim second to get the second account (102)
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
ARG SASL_XOAUTH2_GIT_REF=release-0.25

RUN        --mount=type=cache,target=/var/cache/apt,sharing=locked,id=var-cache-apt-$TARGETPLATFORM \
           --mount=type=cache,target=/var/lib/apt,sharing=locked,id=var-lib-apt-$TARGETPLATFORM \
           --mount=type=tmpfs,target=/etc/apk/cache \
           --mount=type=tmpfs,target=/var/cache/apk \
           --mount=type=tmpfs,target=/tmp \
           --mount=type=tmpfs,target=/sasl-xoauth2 \
           --mount=type=bind,from=build-scripts,source=/build-scripts,target=/build-scripts \
           bash /build-scripts/sasl-build.sh

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

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --start-interval=2s --retries=3 CMD /scripts/healthcheck.sh

EXPOSE     587
CMD        [ "/bin/sh", "-c", "/scripts/run.sh" ]

ENTRYPOINT ["/tini", "--"]
