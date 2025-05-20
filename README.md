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

Build the volsync bundle (this may fail because of cachi env cmd in the dockerfile, so you may need 
to manually edit the bundle.Dockerfile.rhtap)


```bash
podman build --build-arg-file rhtap-buildargs.conf -f bundle.Dockerfile.rhtap -t volsync-bundle:local-build-latest .
```
