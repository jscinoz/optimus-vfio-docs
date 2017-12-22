DefinitionBlock ("", "SSDT", 1, "JSC", "NvOpti-1", 0x00000001) {
    External(\_SB.PCI0.PEG0.PEGP.RBF2, BuffObj)
    External(\_SB.PCI0.PEG0.PEGP.RBF3, BuffObj)
    External(\_SB.PCI0.PEG0.PEGP.RBF4, BuffObj)

    Device (\_SB.PCI0.PEG0) {
        Name (_ADR, 0x00010000)
    }

    Device (\_SB.PCI0.PEG0.PEGP) {
        Name (_ADR, Zero)
    }

    Scope (\_SB.PCI0.PEG0.PEGP) {
        // TODO: Find a way to read from the BAR set up by qemu so this dsdt can
        // be generic
        Name (RBF1, Buffer() {
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

            // Initialise ROMS to a 32k buffer
            Name (ROMS, Buffer (0x8000) { 0 }) 

            // Initialise ROM2 to a buffer of the requested length
            /*
            Name (ROMB, Buffer (Local1)
            {
                 0x00
            })
            */

            If ((Local0 < 0x8000)) {
                // If we're after something in the first 32k, set ROM1 to RBF1
                ROMS = RBF1
            } ElseIf ((Local0 < 0x00010000)) {
                // If we're after something between 32k and 64k, set ROM1 to RBF2
                // Adjust offset to start of new chunk
                Local0 -= 0x8000
                ROMS = RBF2
            } ElseIf ((Local0 < 0x00018000))            {
                // If we're after something between 64k and 96k, set ROM1 to RBF3
                // Adjust offset to start of new chunk
                Local0 -= 0x00010000
                ROMS = RBF3
            } ElseIf ((Local0 < 0x00020000)) {
            // If we're after something between 96k and 128k, set ROM1 to RBF4
                // Adjust offset to start of new chunk
                Local0 -= 0x00018000
                ROMS = RBF4 /* \_SB_.PCI0.PEG0.PEGP.RBF4 */
            }

            // Offset as bits
            Local2 = (Local0 * 0x08)

            // Copy contents of ROM1 starting at our bit offset (Local2) to the
            // the length in bits (Local3) to a new buffer, TMPB
            CreateField (ROMS, Local2, Local3, TMPB)


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
