# volsync-operator-product-build
VolSync Operator Product Build to build downstream VolSync via Konflux

## Getting Started

This repo contains submodules in order to have all the dependencies
to build the VolSync Operator.

Current submodules:

- [volsync](volsync) - points to https://github.com/volsync/volsync
- [rclone](rclone) - points to https://github.com/rclone/rclone
- [syncthing](syncthing) - points to https://github.com/syncthing/syncthing
- [diskrsync](diskrsync) - points to https://github.com/dop251/diskrsync
- [yq](yq) - points to https://github.com/mikefarah/yq - This submodule is only needed for editing the CSV yaml
 with custom edits for Red Hat in bundle-hack/update-bundle.sh during the bundle build

To clone this repo and submodules it can be done in one step with:

```bash
git clone https://github.com/stolostron/volsync-operator-product-build.git --recurse-submodules
```

Or, after cloning the repo you can do this to pull the submodules:

```bash
cd volsync-operator-product-build
git submodule update --init --recursive
```

## Building locally

To build locally and simulate/exercise what the konflux build will do, you can do the following:


Build the volsync container

```bash
podman build --build-arg-file rhtap-buildargs.conf -f Dockerfile.rhtap -t volsync-container:local-build-latest .
```

Build the volsync bundle

```bash
podman build --build-arg-file rhtap-buildargs.conf -f bundle.Dockerfile.rhtap -t volsync-bundle:local-build-latest .
```

### Editing RPM dependencies

If any dependencies are added or removed in the Dockerfiles then we will need to update [rpms.in.yaml](rpms.in.yaml)
and [rpms.lock.yaml](rpms.lock.yaml)

Using the [rpm-lockfile-prototype tool](https://github.com/konflux-ci/rpm-lockfile-prototype)

Steps to run it as a container (this has some manual steps as it seems we need to manually login to registry.redhat.io)

1. First update the rpms.in.yaml
1. Now start the container

```bash
container_dir=/work
podman run -it --entrypoint=/bin/bash -v ${PWD}:${container_dir} localhost/rpm-lockfile-prototype:latest
```

1. Exec into the container and run the following:

```bash
skopeo login registry.redhat.io
...
rpm-lockfile-prototype --outfile=/work/rpms.lock.yaml /work/rpms.in.yaml
```
