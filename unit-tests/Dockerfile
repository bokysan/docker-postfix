ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION} as build

ARG SASL_XOAUTH2_REPO_URL=https://github.com/tarickb/sasl-xoauth2.git
ARG SASL_XOAUTH2_GIT_REF=release-0.9

RUN        true && \
           apk add --no-cache --upgrade git && \
           apk add --no-cache --upgrade cmake clang make gcc g++ libc-dev pkgconfig curl-dev jsoncpp-dev cyrus-sasl-dev && \
           git clone --depth 1 --branch ${SASL_XOAUTH2_GIT_REF} ${SASL_XOAUTH2_REPO_URL} /sasl-xoauth2  && \
           cd /sasl-xoauth2 && \
           mkdir build && \
           cd build && \
           cmake -DCMAKE_INSTALL_PREFIX=/ .. && \
           make

FROM alpine:${ALPINE_VERSION}
LABEL maintaner="Bojan Cekrlic - https://github.com/bokysan/docker-postfix/"

RUN        true && \
           apk add --no-cache --upgrade cyrus-sasl cyrus-sasl-plain cyrus-sasl-login && \
           apk add --no-cache postfix && \
           apk add --no-cache opendkim && \
           apk add --no-cache --upgrade ca-certificates tzdata supervisor rsyslog musl musl-utils bash opendkim-utils && \
           apk add --no-cache --upgrade libcurl jsoncpp && \
           (rm "/tmp/"* 2>/dev/null || true) && (rm -rf /var/cache/apk/* 2>/dev/null || true)
RUN        apk add --no-cache bash bats && \
           (rm "/tmp/"* 2>/dev/null || true) && (rm -rf /var/cache/apk/* 2>/dev/null || true)

# Copy SASL-XOAUTH2 plugin
COPY       --from=build /sasl-xoauth2/build/src/libsasl-xoauth2.so /usr/lib/sasl2/

WORKDIR    /code
ENTRYPOINT ["/usr/bin/bats"]
CMD        ["-v"]