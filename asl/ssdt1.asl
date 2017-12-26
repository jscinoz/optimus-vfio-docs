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
        Name (ROMB, Buffer(Zero) {})

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
        Method (FWR, One, NotSerialized) {
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

            Local0 = ToString(FWR(4))

            If ("QEMU" != Local0) {
                Debug = "Missing fw_cfg signature"
                Return (One)
            }

            Return (Zero)
        }

        // Loads the fw_cfg file directory
        Method (FDIR, Zero, NotSerialized) {
            // 0x19 = FW_CFG_FILE_DIR
            CTRL = 0x19

            // First four bytes of FW_CFG_FILE_DIR, containing the entry count
            Local0 = FWR(4)

            // Number of fw_cfg files (XXX: Is this conversioni correct?)
            // FIXME: Conversion is probably wrong, length value is big endian
            Local1 = Local0 >> 24

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
            FLST = FWR(Local2)

            Return (Local3)
        }

        // Returns the file at the specified index in the provided FW_CFG_FILE_DIR
        Method(FILG, 2, NotSerialized) {
            // FW_CFG_FILE_DIR
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

            Debug = "Local0"
            Debug = Local0

            // Name field of file
            CreateField(Local0, 64, 56 * 8, FNAM)

            // FIXME: Seems we have a dodgy offset or something?

            Debug = "FNAM"
            Debug = FNAM
            Debug = "ToString(FNAM)"
            Debug = ToString(FNAM)
            Debug = "ToString(FNAM, 56)"
            Debug = ToString(FNAM, 56)

            Return (ToString(FNAM))
        }

        // Finds the selector for our target file in the given fw_cfg directory
        // TODO: Take PCI ids as parameters so this can be hardware-independent
        Method (FWGS, 2, NotSerialized) {
            // FW_CFG_FILE_DIR
            Local0 = Arg0
            // Target filename
            Local1 = Arg1

            // File count (as DWord buffer)
            CreateDWordField(Local0, 0, FCNT)

            // File count as int (is this conversion correct?)
            // FIXME: Conversion is probably wrong, length value is big endian
            Local2 = FCNT >> 24

            // File list
            CreateField(Local0, 4 * 8, Local2 * 64 * 8, FLST)

            For (Local3 = 0, Local3 < Local2, Local3++) {
                // Current file
                Local4 = FILG(Local0, Local3);

                // Current file name
                Local5 = GFN(Local4)

                Debug = "GFN result:"
                Debug = Local5

                If (Local5 == Local1) {
                    Debug = "FOUND TARGET FILE,"

                    // Selector field of current file
                    CreateField(Local4, 32, 16, FSEL)

                    // XXX: Selector is big endian
                    Debug = "FSEL"
                    Debug = FSEL

                    Return (FSEL)
                }
            }

            Return (Zero)
        }


        // Read the fw_cfg file identified by the given selector and return its
        // contents as a buffer
        Method (FRD, One, NotSerialized) {
            // Selector for fw_cfg file to load
            Local0 = Arg0

            // TODO

            Return (Buffer(Zero) {})
        }

        // Retrieves the VBIOS from qemu fw_cfg space.
        Method (ROMG, Zero, NotSerialized) {
            If (ROML == One) {
                // Debug = "ROMG Already Run!"
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

            // Our target file's selector
            Local1 = FWGS(Local0, "10de:139b:4136:1764")

            Debug = "FWGS"
            Debug = Local1

            If (Local1 == Zero) {
                Debug = "Could not find target fw_cfg file"
                Return ()
            }

            ROMB = FRD(Local1)

            Debug = "ROMB"
            Debug = ROMB

            ROML = One
        }

        // XXX: Should this be Serialized or NotSerialized?
        // NotSerialized in bare metal SSDT, should it be?
        Method (_ROM, 2, NotSerialized) {
            // Load the VBIOS into memory, if needed
            ROMG()

            // XXX: Removeme
            ROML = One

            // Bail early for now
            Return (Buffer (Arg1) {})

            // Offset in bytes
            Local0 = Arg0
            // Length in bytes
            Local1 = Arg1

            // Clamp length to 4k as per ACPI spec
            If ((Local1 > 0x1000)) {
                Local1 = 0x1000
            }

            // FIXME: 128k is just based on our ROM. Use the size from the
            // fw_cfg file
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

            Return (TMPB)
        }
    }
}
