FROM scratch AS ctx

COPY ./packages /packages
COPY ./files /files

FROM cgr.dev/chainguard/wolfi-base AS builder

# This allows using this container to make a deployment.
RUN ln -s sysroot/ostree /ostree

# We need the ostree hook.
RUN install -d /mnt/etc
COPY --from=ctx /files/ostree.conf /mnt/etc/dracut.conf.d/
COPY --from=ctx /files/wolfi-defaultfs.conf /mnt/usr/lib/bootc/install/

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
    podman \
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


# Add ostree tmpfile
COPY --from=ctx files/ostree-0-integration.conf /mnt/usr/lib/tmpfiles.d/
COPY --from=ctx files/prepare-root.conf /mnt/usr/lib/ostree/

RUN --mount=type=bind,from=ctx,source=/,target=/ctx apk add --allow-untrusted \
    /ctx/packages/$(arch)/composefs*.apk \
    /ctx/packages/$(arch)/ostree*.apk \
    /ctx/packages/$(arch)/kernel*.apk

RUN mkdir -p /mnt/sysroot/ostree && \
    ostree init --repo /mnt/sysroot/ostree/repo --verbose

RUN ostree commit --repo /mnt/sysroot/ostree/repo --branch latest --bootable /mnt --no-xattrs --verbose

# Turn the pacstrapped rootfs into a container image.
FROM scratch
COPY --from=builder /mnt /

# Generate initramfs
RUN ln -s /usr/lib/modules /lib/modules
RUN --mount=type=tmpfs,dst=/var/tmp /usr/bin/dracut --no-hostonly --kver "6.13.6" --reproducible --zstd -v -f "/usr/lib/modules/6.13.6/initramfs.img"

# Alter root file structure a bit for ostree
RUN mkdir -p /sysroot/ostree /efi /boot && \
    rm -rf /boot/* /var/log /home /root /usr/local /srv && \
    ln -s /sysroot/ostree /ostree && \
    ln -s /var/home /home && \
    ln -s /var/roothome /root && \
    ln -s /var/usrlocal /usr/local && \
    ln -s /var/srv /srv

# Necessary labels
LABEL containers.bootc 1
