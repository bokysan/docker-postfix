# Changed this to specific alpine version so it doesn't get refreshed / pulled from Docker hub every time.
ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION} as build

ARG SASL_XOAUTH2_REPO_URL=https://github.com/tarickb/sasl-xoauth2.git
ARG SASL_XOAUTH2_GIT_REF=release-0.24
COPY *.patch /build-scripts/

RUN        true && \
           apk add --no-cache --upgrade git && \
           apk add --no-cache --upgrade cmake clang make gcc g++ libc-dev pkgconfig curl-dev jsoncpp-dev cyrus-sasl-dev patch
RUN        git clone --depth 1 --branch ${SASL_XOAUTH2_GIT_REF} ${SASL_XOAUTH2_REPO_URL} /sasl-xoauth2
WORKDIR    /sasl-xoauth2
RUN        mkdir build && \
           cd build && \
           patch -p1 -d .. < /build-scripts/sasl-xoauth2-01.patch && \
           patch -p1 -d .. < /build-scripts/sasl-xoauth2-02.patch && \
           cmake -DCMAKE_INSTALL_PREFIX=/ .. && \
           make

FROM alpine:${ALPINE_VERSION}
LABEL maintaner="Bojan Cekrlic - https://github.com/bokysan/docker-postfix/"

RUN        true && \
           apk add --no-cache --upgrade cyrus-sasl cyrus-sasl-static cyrus-sasl-digestmd5 cyrus-sasl-crammd5 cyrus-sasl-login cyrus-sasl-ntlm && \
           apk add --no-cache postfix && \
           apk add --no-cache opendkim && \
           apk add --no-cache rspamd && \
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