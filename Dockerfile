# syntax=docker/dockerfile:1.6

# Note:
# The BASE_IMAGE can be changed for this docker image. In fact, it will be. Check .github/workflows/master.yml.
# This image is automatically built with Debian, Ubuntu and Alpine as underlying systems. Each of these has its
# own advantages and shortcomings. In essence:
#
# - use Alpine if you're strapped for space. But beware it uses MUSL LIBC, so unicode support might be an issue.
# - use Debian if you're interested in the greatest cross-platform compatibility. It is larger than Alpine, though.
# - use Ubuntu if, well, Ubuntu is your thing and you're used to the Ubuntu ecosystem.
ARG BASE_IMAGE=debian:trixie-slim

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

# Pending release 0.26, we are pulling the latest "well-known" commit from the master
# as [build fails](https://github.com/bokysan/docker-postfix/actions/runs/20154830240/job/57855111679?pr=255#step:6:427)
#ARG SASL_XOAUTH2_GIT_REF=release-0.25
ARG SASL_XOAUTH2_GIT_REF=1f5d78cae6fc0debe4f485c1571c67dfccb04466

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
LABEL org.opencontainers.image.source="https://github.com/bokysan/docker-postfix/"
LABEL org.opencontainers.image.authors="bokysan"
LABEL org.opencontainers.image.title="docker-postfix"

ARG TARGETPLATFORM

# Set up configuration
COPY       image_root/  /

RUN        true && \
           if [ -d /etc/postfix ]; then cp -r /etc/postfix /etc/postfix.default; fi && \
           if [ -d /etc/opendkim ]; then cp -r /etc/opendkim /etc/opendkim.default; fi && \
           if [ -d /etc/rspamd ]; then cp -r /etc/rspamd /etc/rspamd.default; fi && \
           if [ -f /etc/aliases ]; then postalias /etc/aliases; fi && \
           chmod +x /scripts/* && \
           echo "DOCKER_POSTFIX_BUILT_AT=\"$(date "+%Y-%m-%dT%H:%M:%S%z")\"" >> /etc/docker-postfix_release \
           echo "DOCKER_POSTFIX_TARGETPLATFORM=\${TARGETPLATFORM}" >> /etc/docker-postfix_release \
           true

# Set up volumes
VOLUME     [ \
    "/etc/rsyslog.d/" \
    "/etc/rsyslog.d-before/" \
    "/etc/rsyslog.d-metrics/" \
    "/var/run/", \
    "/var/spool/postfix", \
    "/var/lib/postfix", \
    "/etc/postfix", \
    "/etc/rspamd/", \
    "/etc/opendkim/keys" \
]

# Run supervisord
USER       root
WORKDIR    /tmp

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --start-interval=2s --retries=3 CMD /scripts/healthcheck.sh

EXPOSE     587
CMD        [ "/bin/sh", "-c", "/scripts/run.sh" ]

ENTRYPOINT ["/tini", "--"]
