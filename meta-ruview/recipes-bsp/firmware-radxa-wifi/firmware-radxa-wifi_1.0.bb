SUMMARY = "Broadcom BCM43456 / AP6256 WiFi + BT firmware for Radxa Zero (validated S125, board 1 on MANGO-WPA)"
DESCRIPTION = "Radxa-official brcmfmac43456 SDIO firmware + AP6256 NVRAM + BCM4345C5 BT patch. \
Chip auto-detected as BCM4345/9. Replaces linux-firmware-bcm43430 (wrong chip)."
LICENSE = "CLOSED"

SRC_URI = "\
    file://brcmfmac43456-sdio.bin \
    file://brcmfmac43456-sdio.clm_blob \
    file://brcmfmac43456-sdio.txt \
    file://BCM4345C5.hcd \
"
S = "${WORKDIR}"

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/brcm
    install -m 0644 ${WORKDIR}/brcmfmac43456-sdio.bin      ${D}${nonarch_base_libdir}/firmware/brcm/
    install -m 0644 ${WORKDIR}/brcmfmac43456-sdio.clm_blob ${D}${nonarch_base_libdir}/firmware/brcm/
    install -m 0644 ${WORKDIR}/brcmfmac43456-sdio.txt      ${D}${nonarch_base_libdir}/firmware/brcm/
    install -m 0644 ${WORKDIR}/BCM4345C5.hcd               ${D}${nonarch_base_libdir}/firmware/brcm/
    # board-specific names the kernel probes for (DT compatible "radxa,zero")
    ln -sf brcmfmac43456-sdio.txt ${D}${nonarch_base_libdir}/firmware/brcm/brcmfmac43456-sdio.radxa,zero.txt
    ln -sf BCM4345C5.hcd          ${D}${nonarch_base_libdir}/firmware/brcm/BCM4345C5.radxa,zero.hcd
}
FILES:${PN} = "${nonarch_base_libdir}/firmware/brcm"
