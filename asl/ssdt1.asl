DefinitionBlock ("", "SSDT", 1, "JSC", "NVHACK", 0x00000002) {
    External(\_SB.PCI0.FWCF, DeviceObj)
    External(\_SB.PCI0.FWCF._CRS, BuffObj)

    Device (\_SB.PCI0.PEG0) {
        Name (_ADR, 0x00010000)
    }

    Device (\_SB.PCI0.PEG0.PEGP) {
        Name (_ADR, Zero)

        // Flag for whether we've already loaded the ROM or not
        Name (ROML, Zero)

        // Buffer to hold ROM data read from fw_cfg
        Name (ROMB, Buffer(0x20000) { })

        CreateByteField(\_SB.PCI0.FWCF._CRS, 0, ID)
        CreateWordField(\_SB.PCI0.FWCF._CRS, 2, BMIN)
        CreateWordField(\_SB.PCI0.FWCF._CRS, 4, BMAX)
        CreateByteField(\_SB.PCI0.FWCF._CRS, 7, LEN)

        // XXX: Unsure why, but these must be two separate regions, even though
        // FWD is entirely contained within FWC
        OperationRegion(FWC, SystemIO, BMIN, 2)
        OperationRegion(FWD, SystemIO, BMIN + 1, 1)
        Field(FWC, WordAcc, Lock, Preserve) {
            CTRL, 16
        }

        // Yes, DATA overlaps CTRL. This is not a mistake
        Field(FWD, ByteAcc, NoLock, Preserve) {
            DATA, 8
        }
    }

    Scope (\_SB.PCI0.PEG0.PEGP) {
        // Read the requested number of bytes from fw_cfg, returning it in a
        // buffer
        Method (FWRD, One, NotSerialized) {
            // Byte length
            Local0 = Arg0

            // Output buffer
            Local1 = Buffer(Local0) {}

            for (Local2 = 0, Local2 < Local0, Local2++) {
                Index(Local1, Local2) = DATA
            }

            Return (Local1)
        }

        // Verify fw_cfg is set up properly
        Method(FWV, Zero, NotSerialized) {
            If (ID != 0x47) {
                Debug = "ID wasn't 0x47, got:"
                Debug = ID
                Return (One)
            }

            // Length will be either 12 if DMA is enabled (which we won't use in
            // any case), or 8 otherwise.
            if (BMIN != BMAX || (LEN != 12 && LEN != 8)) {
                Debug = "Don't know how to deal with multiple I/O ports"
                Return (One)
            }

            // 0x0 = FW_CFG_SIGNATURE
            CTRL = Zero

            Local0 = ToString(FWRD(4))

            If ("QEMU" != Local0) {
                Debug = "Missing fw_cfg signature"
                Return (One)
            }

            Return (Zero)
        }

        // uint16 byte (endianness) swap
        Method (BS16, One, NotSerialized) {
            // Input Word buffer
            Local0 = Arg0

            Return ((Local0 << 8) | (Local0 >> 8))
        }

        // uint32 byte (endianness) swap
        Method (BS32, One, NotSerialized) {
            // Input DWord buffer
            Local0 = Arg0

            Local1 = Local0 << 8 & 0xFF00FF00 | Local0 >> 8 & 0x00FF00FF

            Return ((Local1 << 16) | (Local1 >> 16))
        }

        // Loads the fw_cfg file directory
        Method (FDIR, Zero, NotSerialized) {
            // 0x19 = FW_CFG_FILE_DIR
            CTRL = 0x19

            // First four bytes of FW_CFG_FILE_DIR, containing the entry count
            Local0 = FWRD(4)

            // Number of fw_cfg files
            Local1 = BS32(Local0)

            // Total byte count to read (One fw_cfg file = 64 bytes)
            Local2 = Local1 * 64

            // TODO: Assertions / check that we're doing the right thing

            // Output buffer (+4 bytes for the count)
            Local3 = Buffer(Local2 + 4) {}

            // File count
            CreateDWordField(Local3, 0, FCNT)

            // File list
            CreateField(Local3, 4 * 8, Local2 * 8, FLST)

            // Copy first four bytes in
            FCNT = Local0

            // Copy the file list in
            FLST = FWRD(Local2)

            Return (Local3)
        }

        // Returns the file count field as an integer, from the provided
        // FW_CFG_FILE_DIR struct
        Method(GFC, One, NotSerialized) {
            // FW_CFG_FILE_DIR
            Local0 = Arg0

            // File count (as DWord buffer, big-endian)
            CreateDWordField(Local0, 0, FCNT)

            Return (BS32 (FCNT))
        }

        // Returns the file list field from the provided FW_CFG_FILE_DIR struct,
        // using the provided file count
        Method (GFL, 2, NotSerialized) {
            // FW_CFG_FILE_DIR
            Local0 = Arg0
            // File count
            Local1 = Arg1

            // File list
            CreateField(Local0, 4 * 8, Local1 * 64 * 8, FLST)

            return (FLST)
        }

        // Returns the file at the specified index in the provided file list
        Method(FILG, 2, NotSerialized) {
            // File list
            Local0 = Arg0
            // File index
            Local1 = Arg1

            // File within file list
            CreateField(Local0, Local1 * 64 * 8, 64 * 8, FILE)

            Return (FILE)
        }

        // Returns the name of the provided fw_cfg file
        Method(GFN, One, NotSerialized) {
            // A buffer containing a fw_cfg_file struct
            Local0 = Arg0

            // Name field of file
            CreateField(Local0, 64, 56 * 8, FNAM)

            Return (ToString(FNAM))
        }

        // Finds the selector for our target file in the given fw_cfg directory
        // TODO: Take PCI ids as parameters so this can be hardware-independent
        Method (FWGS, 2, NotSerialized) {
            // FW_CFG_FILE_DIR
            Local0 = Arg0
            // Target filename
            Local1 = Arg1
            // File count
            Local2 = GFC(Local0)
            // File list
            Local3 = GFL(Local0, Local2)

            For (Local4 = 0, Local4 < Local2, Local4++) {
                // Current file
                Local5 = FILG(Local3, Local4);

                // Current file name
                Local6 = GFN(Local5)

                If (Local6 == Local1) {
                    Return (Local5)
                }
            }

            Return (Buffer() { 0 })
        }

        // Reads the given fw_cfg_file and returns a buffer of its contents
        Method (FWLD, One, NotSerialized) {
            // Selector for fw_cfg file to load
            Local0 = Arg0

            // File size as a big-endian dword
            CreateDWordField(Local0, 0, SIZE)
            // Selector
            CreateWordField(Local0, 4, FSEL)

            // File size as int
            Local1 = BS32(SIZE)
            // Selector address
            Local2 = BS16(FSEL)

            // Set the ctrl register to our selector
            CTRL = Local2

            Return (FWRD (Local1))
        }

        // Retrieves the VBIOS from qemu fw_cfg space.
        Method (ROMG, Zero, NotSerialized) {
            If (ROML == One) {
                Return ()
            }

            If (FWV()) {
                Debug = "fw_cfg verification failed"
                Return ()
            }

            // FW_CFG_FILE_DIR
            Local0 = FDIR()

            If (SizeOf(Local0) == Zero) {
                Debug = "Loading FW_CFG_FILE_DIR failed"
                Return ()
            }

            // Our target file
            Local1 = FWGS(Local0, "genroms/10de:139b:4136:1764")

            If (SizeOf(Local1) == One) {
                Debug = "Could not find target fw_cfg file"
                Return ()
            }

            ROMB = FWLD(Local1)

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

            // Clamp length to 4k as per ACPI spec
            If ((Local1 > 0x1000)) {
                Local1 = 0x1000
            }

            // Bail if offset > our ROM size
            // FIXME: Should account for length here
            If (Local0 > SizeOf(ROMB)) {
                Return (Buffer (Local1) {})
            }

            // Length as bits
            Local3 = Local1 * 8

            // Offset as bits
            Local2 = Local0 * 8

            // Create a field representing the requested window into the ROM
            // data
            CreateField (ROMB, Local2, Local3, TMPB)

            Return (TMPB)
        }
    }
}
