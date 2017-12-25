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
        Name (ROMB, Buffer(0x20000) {})
    }

    Scope (\_SB.PCI0.PEG0.PEGP) {
        // Gets the option ROM from the device (this will be the content from
        // qemu's romfile option) and loads it into a local Buffer.
        Method (ROMG, Zero, Serialized) {
            If (ROML == One) {
                // Debug = "ROMG Already Run!"
                Return ()
            }

            OperationRegion (EROM, PCI_Config, 0x30, 0x4)
            Field(EROM, AnyAcc, Lock, Preserve) {
                // Enabled flag
                REN,  1,
                // Reserved - not used
                ,     10,
                // Base address of ROM image
                // Note that this needs to be left-shifted by 12 on reads, and
                // right-shfited by 11 on writes
                BASE, 21,
            }

            // Clear BAR
            // BAR = Zero

            // Enable reading ROM
            REN = One

            OperationRegion (VROM, SystemMemory, BASE << 11, 0x20000)
            Field(VROM, AnyAcc, Lock, Preserve) {
                VRM, 0x100000
            }

            // Seems correct, under BIOS boot only.
            ROMB = VRM

            // Clean up - disable ROM reading
            REN = Zero

            ROML = One
        }

        // XXX: Should this be Serialized or NotSerialized?
        // NotSerialized in bare metal SSDT, should it be?
        Method (_ROM, 2, NotSerialized) {
            // Load the VBIOS into memory, if needed
            ROMG()

            // Offset in bytes
            Local0 = Arg0
            // Length in bytes
            Local1 = Arg1

            // Clamp length to 4k
            // XXX: Nouveau is happy to read larger chunks, if we don't clamp.
            // Need to see how the nvidia driver behaves
            If ((Local1 > 0x1000)) {
                Local1 = 0x1000
            }

            // Bail if offset > 128k
            If ((Local0 > 0x20000)) {
                Return (Buffer (Local1) {})
            }

            // Length as bits
            Local3 = Local1 * 8

            // Offset as bits
            Local2 = Local0 * 8

            // Create a field representing the requested window into the ROM
            // data
            CreateField (ROMB, Local2, Local3, TMPB)

            // Return (ROM2)
            Return (TMPB)
        }
    }
}
