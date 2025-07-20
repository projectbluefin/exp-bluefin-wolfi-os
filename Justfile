generate-signing-key:
    #!/usr/bin/env bash
    podman run \
        --rm -it -v "${PWD}:/work:Z" --privileged \
        cgr.dev/chainguard/melange \
        keygen

# build $package="":
#     #!/usr/bin/env bash
#     mkdir -p ./output/packages
#     podman run \
#         --rm -it -v "${PWD}:/work:Z" --privileged \
#         cgr.dev/chainguard/melange \
#         --pipeline-dir /work/pipelines \
#         --workspace-dir /work \
#         build "packages/${package}/melange.yaml" --arch host --signing-key melange.rsa --out-dir ./output/packages/

build $package="":
     #!/usr/bin/env bash
     mkdir -p ./output/packages
     QEMU_KERNEL_IMAGE=./tmp/kernel-core/usr/lib/6.15.6/vmlinuz melange \
         --pipeline-dir ./pipelines \
         --workspace-dir . \
         --runner qemu \
         --log-level debug \
         build "packages/${package}/melange.yaml" --arch host --signing-key melange.rsa --out-dir ./output/packages/

apko-build $yaml="apko.yaml" $tag="bootc-os:local" $tar="bootc-os.tar":
    #!/usr/bin/env bash
    mkdir -p ./output/oci
    podman run \
        --rm -it -v "${PWD}:/work:Z" --privileged \
        cgr.dev/chainguard/apko \
        --workdir /work \
        --sbom-path ./output/oci \
        build "${yaml}" "${tag}" ./output/oci/"${tar}"
    podman load < ./output/oci/"${tar}"

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
