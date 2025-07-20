# From wolfi base image
FROM cgr.dev/chainguard/wolfi-base:latest

RUN apk add --no-cache \
    ca-certificates-bundle \
    wolfi-base \
    systemd \
    podman \
    bash

RUN apk add --no-cache coreutils util-linux

# Create /var/tmp
RUN mkdir -p /var/tmp && \
    chmod 1777 /var/tmp

COPY ./output /work/output

RUN apk add --no-cache --allow-untrusted \
    /work/output/packages/x86_64/kernel-core-*.apk \
    /work/output/packages/x86_64/kernel-headers-*.apk \
    /work/output/packages/x86_64/kernel-modules-*.apk \
    /work/output/packages/x86_64/kernel-initramfs-*.apk \
    /work/output/packages/x86_64/bootupd-*.apk \
    /work/output/packages/x86_64/bootc-*.apk
