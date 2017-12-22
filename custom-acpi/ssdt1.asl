DefinitionBlock ("", "SSDT", 1, "OptRef", "OptTabl", 0x00001000) {
    // XXX: Is this block needed?
    Device (\_SB.PCI0.PEG0) {
        Name (_ADR, 0x00010000)
    }

    Device (\_SB.PCI0.PEG0.PEGP) {
        Name (_ADR, Zero)
    }

    Scope (\_SB.PCI0.PEG0.PEGP) {
        // TODO: Find a way to read from the BAR set up by qemu so this dsdt can
        // be generic
        Name (ROM, Buffer() {
            /* BIOS bytes redacted to avoid DMCA trouble */
        })

        Method (_ROM, 2, NotSerialized) {
            // Offset
            Local0 = Arg0

            // Length
            Local1 = Arg1

            // Clamp length to 4096
            If ((Local1 > 0x1000))
            {
                Local1 = 0x1000
            }

            // Bail if length > 131072
            If ((Local0 > 0x00020000))
            {
                Return (Buffer (Local1)
                {
                     0x00
                })
            }

            // Length as bits
            Local3 = (Local1 * 0x08)

            // Initialise ROM2 to a buffer of the requested length
            /*
            Name (ROMB, Buffer (Local1)
            {
                 0x00
            })
            */

            // Offset as bits
            Local2 = (Local0 * 0x08)

            // Copy contents of ROM1 starting at our bit offset (Local2) to the
            // the length in bits (Local3) to a new buffer, TMPB
            CreateField (ROM, Local2, Local3, TMPB)


            Return (TMPB)
            /*
            // Assign TMPB to ROM2, for some reason. Not sure why TMPB isn't
            // just returnd directly
            ROMB = TMPB

            Return (ROMB)
            */
        }
    }
}
