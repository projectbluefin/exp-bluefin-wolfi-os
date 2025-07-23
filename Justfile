export MELANGE_IMAGE := env("MELANGE_IMAGE", "cgr.dev/chainguard/melange:latest")
export SIGNING_KEY_PATH := env("SIGNING_KEY_PATH", "melange.rsa")
export MELANGE_RUNNER := env("MELANGE_RUNNER", "docker")
export MANIFESTS_DIR := env("MANIFESTS_DIR", "./manifests")
export PACKAGES_DIR := env("PACKAGES_DIR", "./packages")
export KERNEL_DIR := env("KERNEL_DIR", "kernel")
export PIPELINE_DIR := env("PIPELINE_DIR", "./pipelines")
export QEMU_KERNEL_IMAGE := env("QEMU_KERNEL_IMAGE", "./kernel/boot/vmlinuz-virt")
export QEMU_KERNEL_MODULES := env("QEMU_KERNEL_IMAGE", "./kernel/lib/modules")
export MELANGE_OPTS := "
    -i
    --debug
    --log-level=DEBUG
    --arch host
    --repository-append https://packages.wolfi.dev/os
    --keyring-append https://packages.wolfi.dev/os/wolfi-signing.rsa.pub"
export APKO_OPTS := "
    --repository-append https://packages.wolfi.dev/os
    --keyring-append https://packages.wolfi.dev/os/wolfi-signing.rsa.pub"

keygen *$ARGS:
    podman run --rm -it -v "${PWD}:/work:Z" -w /work \
        "${MELANGE_IMAGE}" \
        keygen $ARGS

create-cache-dir:
    mkdir -p ./.cache/apk-cache
    mkdir -p ./.cache/melange
    mkdir -p ./.cache/workspace

build $package="":
    just create-cache-dir
    melange build $MELANGE_OPTS "${MANIFESTS_DIR}/${package}.yaml" \
        --repository-append "${PACKAGES_DIR}" \
        --source-dir "${MANIFESTS_DIR}/${package}" \
        --keyring-append "${SIGNING_KEY_PATH}.pub" \
        --signing-key "${SIGNING_KEY_PATH}" \
        --runner "${MELANGE_RUNNER}" \
        --pipeline-dir "${PIPELINE_DIR}"

test $package="":
    melange test $MELANGE_OPTS "${MANIFESTS_DIR}/${package}.yaml" \
        --repository-append "${PACKAGES_DIR}" \
        --source-dir "${MANIFESTS_DIR}/${package}" \
        --keyring-append "${SIGNING_KEY_PATH}.pub" \
        --runner "${MELANGE_RUNNER}" \
        --pipeline-dirs "${PIPELINE_DIR}" \
        --test-package-append wolfi-base

build-tree:
    echo "This will build all packages required for Wolfi Bootc"
    # just build composefs
    # just build ostree
    # just build bootc

    # just build composefs-rs
    # just build dracut

    just build py3-pefile
    just build systemd
    # just build kernel
    just build kernel-initramfs
    just build kernel-uki

renovate:
    #!/usr/bin/env bash
    GITHUB_COM_TOKEN=$(cat ~/.ssh/gh_renovate) LOG_LEVEL=${LOG_LEVEL:-debug} renovate --platform=local

build-containerfile:
    sudo podman build \
        -t wolfi-bootc:latest .

build-apko $yaml="apko.yaml" $tag="wolfi-bootc:latest" $tar="wolfi-bootc.tar":
    mkdir -p ./output/oci
    apko build $APKO_OPTS \
        --repository-append "./packages" \
        --keyring-append "./${SIGNING_KEY_PATH}.pub" \
        --sbom-path ./output/oci \
        "${yaml}" "${tag}" ./output/oci/"${tar}"
    sudo podman load < ./output/oci/"${tar}"

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -w /data \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /usr/share/factory/etc/containers:/usr/share/factory/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers \
        -v /dev:/dev \
        -v .:/data:Z \
        --security-opt label=type:unconfined_t \
        wolfi-bootc:latest bootc {{ARGS}}

generate-bootable-image:
    #!/usr/bin/env bash
    if [ ! -e ./bootable.img ] ; then
        fallocate -l 20G bootable.img
    fi
    just bootc install to-disk --via-loopback /data/bootable.img --filesystem ext4

fetch-kernel:
    #!/usr/bin/env bash
    set -xeuo pipefail
    mkdir -p "${KERNEL_DIR}"
    KERNEL_PKG="$(curl -sL https://dl-cdn.alpinelinux.org/alpine/edge/main/$(arch)/APKINDEX.tar.gz | tar -Oxz APKINDEX | awk -F':' '$1 == "P" {printf "%s-", $2} $1 == "V" {printf "%s.apk\n", $2}' | grep "linux-lts" | grep -v -e "dev" -e "doc")"
    curl -LSo "${KERNEL_DIR}/linux-virt.apk" "https://dl-cdn.alpinelinux.org/alpine/edge/main/$(arch)/$KERNEL_PKG"
    tar -xf "${KERNEL_DIR}/linux-virt.apk" -C "${KERNEL_DIR}"
