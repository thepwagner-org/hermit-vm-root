# hermit-vm-root

This is the root filesystem used by [hermit-ci](https://github.com/thepwagner/hermit), based on [debian/stable](https://packages.debian.org/stable/).

It is what guest virtual machines boot, so should have all the features you want from builders. While it's packaged as a container image, the resulting filesystem is converted and boot as [a firecracker root filesystem](https://github.com/firecracker-microvm/firecracker/blob/05d8bd25548b6c562e794ed2d90d53952ec21494/docs/rootfs-and-kernel-setup.md#creating-a-rootfs-image).

* It must mount the input and output block devices, `/dev/vdb` and `/dev/vdc` respectively.
* It must use the HTTP proxy listening on the VSOCK CID 2, port 1024 to access the internet.

This implementation is orchestrated by systemd:

* `guestproxy.service` - a golang TCP proxy that forwards connections to the VSOCK proxy.
* `buildkit.service` - [buildkitd](https://github.com/moby/buildkit) to assemble container images.
* `guestbuild.service` - a golang helper that assembles the container from sources on the input volume to a tarball on the output volume.
