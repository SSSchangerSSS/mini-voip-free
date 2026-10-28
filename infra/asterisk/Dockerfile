# Asterisk 22 LTS built from the official source tarball with a REAL verified
# checksum (spec 3.2: no fake checksums, no unknown images, no default secrets).
# Toolchain lock: infra/../toolchain.lock.json — keep ARG values in sync.
FROM debian:12-slim AS build

ARG ASTERISK_VERSION=22.11.0
ARG ASTERISK_SHA256=3bd5ee040509a3d3cd9b1ba9520c18e6ec0a7e7981ca68c457dcd36ba3c54d94

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates bzip2 \
        libssl-dev libncurses5-dev libncursesw5-dev libuuid1 uuid-dev \
        libjansson-dev libxml2-dev libsqlite3-dev libcurl4-openssl-dev \
        libedit-dev libxslt1-dev libsrtp2-dev libspeex-dev libspeexdsp-dev \
        libogg-dev libvorbis-dev libasound2-dev python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src
RUN wget -q "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz" \
    && echo "${ASTERISK_SHA256}  asterisk-${ASTERISK_VERSION}.tar.gz" | sha256sum -c - \
    && tar xzf "asterisk-${ASTERISK_VERSION}.tar.gz"

WORKDIR "/usr/src/asterisk-${ASTERISK_VERSION}"
# bundled pjproject is fetched by the build script below — pinned by the Asterisk
# release itself; the downloaded tarball hash is verified by configure.
RUN contrib/scripts/get_mp3_source.sh || true \
    && contrib/scripts/install_prereq install || true \
    && ./configure --libdir=/usr/lib/x86_64-linux-gnu \
        --with-pjproject-bundled \
        --without-bluetooth --without-dahdi --without-gtk2 --without-isdnnet \
        --without-misdn --without-nbs --without-oss --without-pri --without-pwlib \
        --without-x11 --without-sdl --without-unixodbc --without-postgres \
    && menuselect/menuselect --disable BUILD_NATIVE menuselect.makeopts \
    && menuselect/menuselect --disable chan_sip menuselect.makeopts \
    && menuselect/menuselect --enable BETTER_BACKTRACES menuselect.makeopts \
    && make -j"$(nproc)" \
    && make install \
    && make install-headers

FROM debian:12-slim AS runtime

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates libssl3 libjansson4 libxml2 libsqlite3-0 libcurl4 \
        libedit2 libuuid1 libsrtp2-1 libspeex1 libspeexdsp1 libogg0 libvorbis0a \
        libasound2 tini \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 1001 --home-dir /var/lib/asterisk --no-create-home asterisk

COPY --from=build /usr/lib/x86_64-linux-gnu/ /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/sbin/asterisk /usr/sbin/asterisk
COPY --from=build /usr/sbin/astcanary /usr/sbin/astcanary || true
COPY --from=build /var/lib/asterisk /var/lib/asterisk
COPY --from=build /usr/lib/asterisk /usr/lib/asterisk
COPY --from=build /var/spool/asterisk /var/spool/asterisk

# Config directory comes from the mounted volume (compose) — this image ships none.
RUN mkdir -p /etc/asterisk /var/log/asterisk \
    && chown -R asterisk:asterisk /var/lib/asterisk /var/spool/asterisk /var/log/asterisk /etc/asterisk

USER asterisk
EXPOSE 8088 5038
# RTP/UDP 10000-10199 is declared in compose/host firewall, not here (host networking).
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/sbin/asterisk", "-f", "-U", "asterisk", "-G", "asterisk"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
  CMD asterisk -rx "core show version" > /dev/null 2>&1 || exit 1
