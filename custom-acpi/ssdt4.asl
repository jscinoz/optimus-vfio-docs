DefinitionBlock ("", "SSDT", 1, "JSC", "NvOpti-4", 0x00000001) {
    External(\_SB.PCI0.PEG0.PEGP, DeviceObj)

    Scope (\_SB.PCI0.PEG0.PEGP) {
        Name (RBF4, Buffer() {
            /* BIOS bytes redacted to avoid DMCA trouble */
            0
        })
    }
}
