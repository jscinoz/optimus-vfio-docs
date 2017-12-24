DefinitionBlock ("", "SSDT", 1, "JSC", "Optimus", 0x00000001) {
    Device (\_SB.PCI0.PEG0) {
        Name (_ADR, 0x00010000)
    }

    Device (\_SB.PCI0.PEG0.PEGP) {

        Name (_ADR, Zero)

        // Flag for whether we've already loaded the ROM or not
        Name (ROML, Zero)

        // Buffer to hold ROM data read from device
        // XXX: Does this need to be this large, does assinging to ROMB later
        // copy into this buffer, or replace the object pointed to by ROMB?
        Name (ROMB, Buffer(0x20000) { 0 })

        // XXX: Read OROM here instead of in method?
        // TODO: When is this block evaluated? If this runs while EFI boot
        // services are still available, we might be able to get the vga rom
        // here
    }

    Scope (\_SB.PCI0.PEG0.PEGP) {
        // Gets the option ROM from the device (this will be the content from
        // qemu's romfile option) and loads it into a local Buffer.
        Method (ROMG, Zero, Serialized) {
            If (ROML == One) {
                Debug = "ROMG Already Run!"
                Return ()
            }

            Debug = "Hi from ROMG"

            OperationRegion (EROM, PCI_Config, 0x30, 0x4)
            Field(EROM, AnyAcc, Lock, Preserve) {
                // Base address of ROM image
                BASE, 21,
                // Reserved - not used
                ,     10,
                // Enabled flag
                REN,  1
            }

            Field(EROM, AnyAcc, Lock, Preserve) {
                // Expansion ROM BAR as a whole
                BAR, 32
            }

            // XXX: These two seem wrong. Am I using Field wrong?
            Debug = "BASE initial: "
            Debug = BASE
            Debug = "REN initial: "
            Debug = REN

            // Seems to contain what we'd expect
            Debug = "BAR initial"
            Debug = BAR

            // Clear BAR
            /*
            BAR = Zero

            Debug = "BASE after clearing: "
            Debug = BASE
            Debug = "REN after clearing: "
            Debug = REN
            Debug = "BAR after clearing"
            Debug = BAR
            */

            // Enable reading ROM
            //REN = One
            BAR = BAR | 0x1

            Debug = "BAR post REN = 1: "
            Debug = BAR


            /*
            Debug = "ROMB initial:"
            Debug = ROMB
            */

            OperationRegion (VROM, SystemMemory, BAR & 0xfffffff0, 0x20000)
            Field(VROM, AnyAcc, Lock, Preserve) {
                VRM, 0x100000
            }

            // Seems correct, under BIOS boot only.
            //Debug = VRM

            ROMB = VRM

            /*
            //BASE = ROMB

            Debug = "BASE post BASE assignment: "
            Debug = BASE

            Debug = "BAR post BASE assignment: "
            Debug = BAR

            Debug = "ROMB"
            Debug = ROMB
            */

            /*
            // Clean up - disable ROM and clear region
            REN = 0
            BASE = 0xffffffff
            */

            // Debug = "ROM Loaded - Successfully?"
            Debug = "ROMG END"
            ROML = One
        }

        // XXX: Should this be Serialized or NotSerialized?
        // NotSerialized in bare metal SSDT, should it be?
        Method (_ROM, 2, NotSerialized) {
            Debug = "[JSC] Hello from _ROM method"

            // Load the VBIOS into memory, if needed
            ROMG()

            // Offset in bytes
            Local0 = Arg0
            // Length in bytes
            Local1 = Arg1

            // Clamp length to 4096
            // XXX: Nouveau is happy to read larger chunks, if we don't clamp.
            // Need to see how the nvidia driver behaves
            If ((Local1 > 0x1000)) {
                Local1 = 0x1000
            }

            // Bail if length > 131072
            If ((Local0 > 0x20000)) {
                Return (Buffer (Local1) { 0 })
            }

            // Length as bits
            Local3 = (Local1 * 8)
            // Offset as bits
            Local2 = (Local0 * 8)

            // Create a field representing the requested window into the ROM
            // data
            CreateField (ROMB, Local2, Local3, TMPB)

            Debug = "TMPB"
            Debug = TMPB

            Name(ROM2, Buffer(Local1) { 0 })

            // Is this necessary? why not just return tmpb?
            ROM2 = TMPB;

            Return (ROM2)
        }
    }
}
