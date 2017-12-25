All that follows is relating to muxless/non-MXM Optimus cards, i.e. those that
have no display outputs and show as `3D Controller` in `lspci` output. If you
have a MXM / output-providing card (shows as `VGA Controller` in `lspci`), then
this is not for you. For such devices, see
[@Misairu-G's guide](https://gist.github.com/Misairu-G/616f7b2756c488148b7309addc940b28)

# What works
* Compute workloads (via render nodes) on GVT device
  * You can find a sample program that dispatches a compute shader via render
    nodes [here](https://github.com/elima/gpu-playground/tree/master/render-nodes-minimal)
* Compute workloads (via render nodes) on nvidia card (nouveau)
* Render workloads on the nvidia card with the nouveau driver, with a GVT device
  as the guest's primary GPU
  * I have only tested this with q35. i440fx is untested
  * Subsystem vendor & device Id's must be set with x-pci-sub-vendor-id and
    x-pci-sub-device-id on the qemu vfio-pci device for the nvidia card
  * Nvidia VBIOS must be provided to the guest via libvirt's `<rom file=...>` /
    qemu's `romfile` option on the device
    * VBIOS can be obtained under linux by extracting a BIOS update using [coderobe/VBiosFinder](https://github.com/coderobe/VBiosFinder)
    * Alternatively, when using Windows the VBIOS can be obtained by dumping the system firmware with
      [Universal Bios Backup Toolkit](https://forums.mydigitallife.net/threads/universal-bios-backup-toolkit.9856/)
      and using MMTool to extract the VBIOS fromthe "Option ROMs" section
      * This needs to be done under bare-metal Windows. I use a Windows-To-Go
        install of Server 2016 on a USB (UAS) SSD for this, to leave my
        machine's internal storage alone.
  * I've only tested this with OVMF/UEFI. It may or may not work with seabios
    VMs
  * My dumped VBIOS did **not** have EFI support, but I don't think that is
    necessary when the card has no outputs. rom-parser output for reference:
    ```Valid ROM signature found @0h, PCIR offset 190h
	PCIR: type 0, vendor: 10de, device: 139b, class: 030200
	PCIR: revision 3, vendor revision: 1
	Last image
    ```
  * Guest kernel must booted via OVMF directly, or via a bootloader that
    supports the EFI handover protocol
    * Failure to do this will result in nouveau failing to load vbios via the
      `FIRMWARE` interface
    * Mainline GRUB **does not** have EFI handover support. Fedora (and maybe
      other distros) have their own patches adding support for this in the form
      of the `linuxefi` command
  * No local display output at present; remote display must be used.
* Render workloads on the nvidia card with the nvidia driver, with the GVT
  device as secondary, linked with PRIME
  * Requires a patch to the nvidia driver to fake loading VBIOS from ACPI. See
    below
* Render workloads on the GVT device, with the GVT device as the guest's primary
  GPU
  * Only tested on q35 + OVMF
  * No VBIOS needed, everything should Just Work™
  * No local display output at present; remote display must be used.

# What works, with patching
* Binary nvidia driver (Linux)
  * For Optimus cards, it will only attempt to load VBIOS via ACPI \_ROM method,
    which won't exist in the guest.
  * We can probably patch `nv_acpi_rom_method` in `kernel/nvidia/nv-acpi.c` to
    simply return our VBIOS from a hard-coded buffer, just for testing
    * **[UPDATE]** I tested this and it worked, the binary driver booted and the
      NVIDIA card can be set up with PRIME. [glxinfo](glxinfo-nvidia-guest),
			[patch](nvidia-firmware-hack.patch). Note you'll need to dump your own VBIOS and
			inline it in the patch.
  * Long term we need to build a custom ACPI table (provided to qemu with the
    `-acpitable` option) that has `_ROM` implemented at the correct path. The
    `_ROM` implementation would need to seek over a hard-coded buffer stored
    elsewhere and return the VBIOS in 4kb chunks as expected by nvidia driver

# What doesn't work (yet)
* Windows guest
  * Will need custom ACPI table to get VBIOS, as detailed above
* Reverse PRIME to mirror GVT display to QXL device to use Qemu's built in spice
  server
  * The `modesetting` DDX must be used with QXL, as the `qxl` DDX lacks PRIME
    support
  * The QXL-backed modesetting instance can be set up as a PRIME output provider
    successfully, and modes will show as available on the newly created
    Virtual-X-Y output (where X and Y will vary depending on your xorg server's
    layout)
  * Attempting to set any mode on the Virtual-X-Y output will fail with the
   following errors from the kernel:
    ```
    qxl 0000:00:03.0: swiotlb buffer is full (sz: 299008 bytes)
    qxl 0000:00:03.0: DMA: Out of SW-IOMMU space for 299008 bytes
    ```
    * Next step may be to try with Qemu's emulated `intel-iommu` device and see
      if this helps
* QXL as primary xorg GPU with GVT/nvidia as secondary
  * QXL-backed modesetting provides only the `Sink Output` capability. `Sink
    Offload` is required for render offloading to a device with `Source Offload`
    * Maybe QXL could be improved to have the `Sink Offload` capability?
  * Attempting to set up nouveau as the `Source Offload` for the GVT card (which
    has `Sink Offload`) will crash Xorg with the following assertion failure:
    `xorg-server-1.19.5/dix/dispatch.c:4035: AttachOutputGPU: Assertion 'new->current_master == pScreen' failed.`
    This suggests that PRIME render offload requires the destination device (the
    one being used as a `Sink Offload` to be the primary Xorg GPU
* Bumblebee
  * Attempting to use bumblebee without a GVT device will fail as `bumblebeed`
    will bail out at startup upon not finding an Intel card
    * Patching out this check will allow `bumblebeed` to start.
  * Once `bumblebeed` has started, it is unable to successfully start the
    secondary X server, as the nvidia card has no outputs and Xorg bails out due
    to no outputs existing.
    * Nouveau does **not** support/have the `AllowEmptyInitialConfiguration`
      option that the proprietary nvidia driver has.

# What will (probably) never work
* Using the nvidia card in the guest as the sole GPU
  * As non-MXM Optimus cards lack any outputs, xorg will not start as there are
    no outputs available
  * xf86-video-dummy cannot be used as the primary GPU as it lacks PRIME support

# What's untested
* Wayland

# What's needed
* A way to obtain a dump of nvidia VBIOS under Linux
  * Try [coderobe/VBiosFinder](https://github.com/coderobe/VBiosFinder)
* Custom ACPI tables embedding nvidia VBIOS and exposing it via the `_ROM`
  method at the appropriate path
