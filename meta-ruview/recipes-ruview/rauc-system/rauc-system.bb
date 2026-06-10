SUMMARY = "RAUC system configuration for radxa-zero fleet"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
SRC_URI = "file://system.conf file://development-1.cert.pem"
FILESEXTRAPATHS:prepend := "${THISDIR}/../../files/rauc:"
S = "${WORKDIR}"
do_install() {
    install -d ${D}${sysconfdir}/rauc
    install -m 0644 ${WORKDIR}/system.conf ${D}${sysconfdir}/rauc/system.conf
    install -m 0644 ${WORKDIR}/development-1.cert.pem ${D}${sysconfdir}/rauc/keyring.pem
}
FILES:${PN} = "${sysconfdir}/rauc/"
