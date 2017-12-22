These are my raw notes taken as I've been experimenting with this, information
in this file could be outdated / wrong - see [README.md](README.md) for
information that should be current (and hopefully accurate)

* For nouveau to find firmware provided by <rom file=...> option, the kernel
  needs to be directly booted via the platform (i.e. EFISTUB), or via EFI
  handover protocol. Fedora and others patch grub to add a 'linuxefi' command
  that does this, but this patch does not appear mainline yet
* Nouveau seems to create a render node, whether anything actually works is TBD


TODO:
* Upload various xorg.confs
* Try with git kernel
* Try with gvt bleeding edge kernel
* Try using qxl + gvt (without nvidia) to debug qxl reverse prime
* Experiment with qemu emulated intel_iommu to see if that resolves the swiotlb
  issue
* Instead of custom DSDT, for linux nvidia driver, hack nvidia-acpi.c to just
  load hard-coded vbios
* Figure out why we need to set up vfio-pci manually and libvirt fails
  * Seems it's setting up VFIO groups wrong?
* Test using nouveau render node directly
  * Tentatively done, but need to actually validate our test methodology
* See if we can debug PRIME issues further
  * So far, setting nvidia as output source for qxl results in BadValue from
    xrandr :(
  * WORKS IF we make gvt device primary gpu!
  * Need to see if we can do reverse prime then mirroring with qxl
    * Running into odd memory issues with qxl reverse prime:
      qxl 0000:00:03.0: swiotlb buffer is full (sz: 299008 bytes)
      qxl 0000:00:03.0: DMA: Out of SW-IOMMU space for 299008 bytes
* Try with bumblebee
  * Didn't work with QXL without patching out check for intel GPU
  * Fails to start second X display on nvidia card due to lack of ouputs
    * Test if bumblebee even works on the host
* Try with wayland
  * So far, wayland just flashes for a bit then freezes
* Test with nvidia as primary VGA
  * Ideally without GVT
  * Can we have reverse prime with non-primary QXL for output?
  * Seems xorg requires a GPU with actual outputs as the primary one.
  * Could try with xf86-video-dummy, but i doubt it has prime?
* custom ACPI table with GPU firmware in it
  * If we still have issues, try adding optimus strings from host ssdt2
* Try with virtio-gpu too
* More testing with GVT
  * Can only set nvidia offload to primary device, assinging to non primary will
    crash xorg with the following assertion failure
    xorg-server-1.19.5/dix/dispatch.c:4035: AttachOutputGPU: Assertion `new->current_master == pScreen` failed.
  * Test with just QXL and gvt for shiggles
    * Doesn't work, QXL has only "Sink Output", nothing else
