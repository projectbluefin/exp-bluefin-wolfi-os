export MELANGE_IMAGE := env("MELANGE_IMAGE", "cgr.dev/chainguard/melange:latest")
export SIGNING_KEY_PATH := env("SIGNING_KEY_PATH", "melange.rsa")
export MELANGE_RUNNER := env("MELANGE_RUNNER", "bubblewrap")
export PACKAGES_DIR := env("PACKAGES_DIR", "manifests")
export MELANGE_OPTS := "
    -i
    --debug
    --log-level=DEBUG
    --arch host
    --pipeline-dir ./pipelines
    --repository-append https://packages.wolfi.dev/os
    --keyring-append https://packages.wolfi.dev/os/wolfi-signing.rsa.pub"
export APKO_OPTS := "
    --repository-append https://packages.wolfi.dev/os
    --keyring-append https://packages.wolfi.dev/os/wolfi-signing.rsa.pub"

create-cache-dir:
    mkdir -p ./.cache/apk-cache
    mkdir -p ./.cache/melange
    mkdir -p ./.cache/workspace

keygen *$ARGS:
    podman run --rm -it -v "${PWD}:/work:Z" -w /work \
        "${MELANGE_IMAGE}" \
        keygen $ARGS

build $package="":
    just create-cache-dir
    melange build $MELANGE_OPTS "${PACKAGES_DIR}/${package}.yaml" \
        --source-dir "./${PACKAGES_DIR}/${package}" \
        --repository-append "./packages" \
        --keyring-append "./${SIGNING_KEY_PATH}.pub" \
        --signing-key "./${SIGNING_KEY_PATH}" \
        --apk-cache-dir "./.cache/apk-cache" \
        --cache-dir "./.cache/melange/${package}" \
        --workspace-dir "./.cache/workspace/${package}" \
        --runner "${MELANGE_RUNNER}"

build-tree:
    echo "This will build all packages required for Wolfi Bootc"
    just build composefs
    just build ostree
    just build bootc
    just build bootupd

    just build composefs-rs
    just build dracut

    just build py3-pefile
    just build systemd
    just build kernel
    just build kernel-initramfs
    just build kernel-uki

renovate:
    #!/usr/bin/env bash
    GITHUB_COM_TOKEN=$(cat ~/.ssh/gh_renovate) LOG_LEVEL=${LOG_LEVEL:-debug} renovate --platform=local

build-containerfile:
    sudo podman build \
        -t wolfi-bootc:latest .

build-apko $yaml="apko.yaml" $tag="wolfi-bootc:latest":
    mkdir -p ./output/oci
    apko build $APKO_OPTS \
        --repository-append "./packages" \
        --keyring-append "./${SIGNING_KEY_PATH}.pub" \
        --sbom-path ./output/oci \
        "${yaml}" "${tag}" ./output/oci/
    sudo skopeo copy oci:./output/oci/ containers-storage:${tag}

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
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
    just bootc install to-disk --composefs-native --via-loopback /data/bootable.img --filesystem ext4 --wipe --bootloader systemd-boot
