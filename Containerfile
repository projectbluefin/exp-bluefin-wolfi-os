FROM scratch AS ctx

COPY ./packages /packages

FROM cgr.dev/chainguard/wolfi-base AS builder

RUN --mount=type=bind,from=ctx,source=/,target=/ctx apk add -X https://packages.wolfi.dev/os --allow-untrusted -U --initdb -p /mnt \
    /ctx/packages/$(arch)/ostree*.apk \
    /ctx/packages/$(arch)/composefs*.apk \
    /ctx/packages/$(arch)/bootc*.apk \
    /ctx/packages/$(arch)/bootupd*.apk \
    /ctx/packages/$(arch)/dracut*.apk \
    /ctx/packages/$(arch)/kernel*.apk \
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
    # TODO: Uncomment once upstream fixes podman dependency with bootc
    #podman \
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

RUN --mount=type=bind,from=ctx,source=/,target=/ctx apk add --allow-untrusted \
    /ctx/packages/$(arch)/composefs*.apk \
    /ctx/packages/$(arch)/ostree*.apk \
    /ctx/packages/$(arch)/bootupd*.apk \
    /ctx/packages/$(arch)/kernel*.apk

# Turn the pacstrapped rootfs into a container image.
FROM scratch
COPY --from=builder /mnt /

# Generate initramfs
RUN ln -s /usr/lib/modules /lib/modules

# Alter root file structure a bit for ostree
RUN mkdir -p /sysroot/ostree /efi /boot && \
    rm -rf /boot/* /var/log /home /root /usr/local /srv && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/usrlocal /usr/local && \
    ln -s /var/srv /srv

# Ostree root settings
COPY ./manifests/composefs-rs/prepare-root.conf /usr/lib/ostree/prepare-root.conf

# Necessary labels
LABEL containers.bootc 1