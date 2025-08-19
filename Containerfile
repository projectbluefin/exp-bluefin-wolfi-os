FROM scratch AS ctx

COPY ./packages /packages

FROM cgr.dev/chainguard/wolfi-base AS builder

RUN --mount=type=bind,from=ctx,source=/packages,target=/repo \
    apk add --allow-untrusted \
        -X /repo \
        -X https://packages.wolfi.dev/os \
        -U --initdb -p /mnt \
    ostree \
    composefs \
    bootc \
    bootupd \
    kernel \
    kernel-modules \
    kernel-initramfs \
    wolfi-base \
    coreutils \
    posix-libc-utils \
    systemd \
    systemd-init \
    systemd-logind-service \
    systemd-boot \
    strace \
    libselinux \
    findmnt \
    btrfs-progs \
    e2fsprogs \
    xfsprogs \
    udev \
    cpio \
    losetup \
    zstd \
    lsblk \
    binutils \
    sfdisk \
    dosfstools \
    conmon \
    crun \
    netavark \
    wipefs \
    skopeo \
    util-linux-login \
    dbus \
    dbus-glib \
    glib \
    shadow

# Turn the pacstrapped rootfs into a container image.
FROM scratch
COPY --from=builder /mnt /

# Alter root file structure a bit for ostree
RUN mkdir -p /boot && \
    rm -rf /var/log /home /root /usr/local /srv && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/usrlocal /usr/local && \
    ln -s /var/srv /srv

# Necessary labels
LABEL containers.bootc 1
