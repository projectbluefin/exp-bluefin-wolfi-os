export MELANGE_IMAGE := env("MELANGE_IMAGE", "cgr.dev/chainguard/melange:latest")
export SIGNING_KEY_PATH := env("SIGNING_KEY_PATH", "melange.rsa")
export MELANGE_RUNNER := env("MELANGE_RUNNER", "docker")
export PACKAGES_DIR := env("PACKAGES_DIR", "manifests")
export MELANGE_OPTS := "
    -i
    --debug
    --log-level=DEBUG
    --fail-on-lint-warning
    --arch host
    --pipeline-dir ./pipelines
    --lint-require
    --lint-warn
    --repository-append https://packages.wolfi.dev/os
    --keyring-append https://packages.wolfi.dev/os/wolfi-signing.rsa.pub"

keygen *$ARGS:
    podman run --rm -it -v "${PWD}:/work:Z" -w /work \
        "${MELANGE_IMAGE}" \
        keygen $ARGS

build $package="":
    melange build $MELANGE_OPTS "${PACKAGES_DIR}/${package}.yaml" --repository-append "./packages" --source-dir "${PACKAGES_DIR}/${package}" --keyring-append "${SIGNING_KEY_PATH}.pub" --signing-key "${SIGNING_KEY_PATH}" --runner "${MELANGE_RUNNER}"

build-tree:
    echo "This will build all packages required for Wolfi Bootc"
    just build composefs
    just build ostree
    just build bootc

    just build dracut
    just build kernel


renovate:
    #!/usr/bin/env bash
    GITHUB_COM_TOKEN=$(cat ~/.ssh/gh_renovate) LOG_LEVEL=${LOG_LEVEL:-debug} renovate --platform=local

build-image:
    sudo podman build \
        -t wolfi-bootc:latest .

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
    just bootc install to-disk --via-loopback /data/bootable.img --filesystem ext4
