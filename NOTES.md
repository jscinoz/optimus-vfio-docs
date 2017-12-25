These are my raw notes taken as I've been experimenting with this, information
in this file could be outdated / wrong - see [README.md](README.md) for
information that should be current (and hopefully accurate)

* For nouveau to find firmware provided by <rom file=...> option, the kernel
  needs to be directly booted via the platform (i.e. EFISTUB), or via EFI
  handover protocol. Fedora and others patch grub to add a 'linuxefi' command
  that does this, but this patch does not appear mainline yet
* Nouveau seems to create a render node, whether anything actually works is TBD


# Current state of ACPI shenanigans
* ASL works under seabios and nvidia driver loads vbios from ACPI successfully
  * But, nvidia drivers has errors once X is started that didn't happen under
    UEFI (with vbios loading faked from inline blob)
  * Windows BSODs with:
    ```
ACPI_BIOS_ERROR:

Arg1: 0000000000001000, ACPI_BIOS_USING_OS_MEMORY
  ACPI had a fatal error when processing a memory operation region.
  The memory operation region tried to map memory that has been
  allocated for OS usage.
    ```
    Seems it is not happy with me reading the option from from bios-assigned
    XROMBAR from within ASL :(
    * Looks like windows may be re-initialising the XROMBAR - the address my ASL
    tries to read when it causes the crash looks nonsense (0xFFFFF800)
* Have not found a way to get the vbios from ASL under OVMF. It seems that once
  OVMF itself has read out option ROMs, they are no longer accessible. I think
  we might need to patch OVMF to retain these maybe generate another SSDT that
  contains OperationRegion for each PCI device with an option rom
  * If we define resources in ACPI for the device (such as a memory region for
    the oprom), will OVMF use these instead? (See:
    PciHostBridgeResourceAllocator, specifically usage of GetResourceBase and
    ProcessOptionRom), ACPI `_PRS`?
    * No, I don't think so, after further analysis of OVMF code

## To try next
* Try reading under efi shell with mm again, but this time, set the memory space
  bit too!
* Figure out GVT issues - only works intermittently
* BIOS
  * Gvt with qxl as primary
  * GVT with qxl as secondary
  * gvt + nvidia, no QXL
  * Windows guest
    * GVT primary, nvidia secondary (matches real hardware)
    * GVT + QXL primary
    * GVT primary + QXL
    * QXL + Nvidia
    * QXL + GVT + Nvidia
* EFI
  * OVMF hack to not clear XROMBAR - see if we can then get to it from ASL

TODO:
* Try in BIOS VM
  * Nouveau can load from pci rom fine, try ACPI
  * Seem to be able to get it from ASL too :O
* Try reading ROM from qemu fw_cfg - might be exposed to ACPI
* Patch OVMF to to have ACPI \_ROM method
  * Tried doing this through ASL, but couldn't find a way to get the ROM data
    from PCI XROMBAR
  * Just have it expose ROMs, still do the rest in ASL
* Try binary nvidia + QXL (no gvt)
* Upload various xorg.confs
* Try with git kernel
* Try with gvt bleeding edge kernel
* Try using qxl + gvt (without nvidia) to debug qxl reverse prime
* Experiment with qemu emulated intel_iommu to see if that resolves the swiotlb
  issue
* See if we can debug PRIME issues further
  * So far, setting nvidia as output source for qxl results in BadValue from
    xrandr :(
  * WORKS IF we make gvt device primary gpu!
  * Need to see if we can do reverse prime then mirroring with qxl
    * Running into odd memory issues with qxl reverse prime:
      qxl 0000:00:03.0: swiotlb buffer is full (sz: 299008 bytes)
      qxl 0000:00:03.0: DMA: Out of SW-IOMMU space for 299008 bytes
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
* Does bumblebee even work on the host?


DONE
* Figure out why we need to set up vfio-pci manually and libvirt fails
  * Seems it's setting up VFIO groups wrong?
* Test using nouveau render node directly
  * Tentatively done, but need to actually validate our test methodology
* Instead of custom DSDT, for linux nvidia driver, hack nvidia-acpi.c to just
  load hard-coded vbios
  * Works
* Try with bumblebee
  * Didn't work with QXL without patching out check for intel GPU
  * Fails to start second X display on nvidia card due to lack of ouputs
    * Test if bumblebee even works on the host
* Try with wayland
  * So far, wayland just flashes for a bit then freezes
