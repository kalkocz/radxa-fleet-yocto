SUMMARY = "NetworkManager WiFi config for HMS Victory fleet"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
SRC_URI = "file://mango-wpa.nmconnection file://00-plugins.conf"
FILESEXTRAPATHS:prepend := "${THISDIR}/../../files/nm:"
S = "${WORKDIR}"
do_install() {
    install -d ${D}${sysconfdir}/NetworkManager/system-connections
    install -m 0600 ${WORKDIR}/mango-wpa.nmconnection \
        ${D}${sysconfdir}/NetworkManager/system-connections/
    sed -i "s/PLACEHOLDER_SET_AT_BUILD_TIME/${MANGO_WPA_PSK}/" \
        ${D}${sysconfdir}/NetworkManager/system-connections/mango-wpa.nmconnection
    # keyfile-only: drop ifupdown plugin so NM manages wlan0 (else it stays unmanaged)
    install -d ${D}${sysconfdir}/NetworkManager/conf.d
    install -m 0644 ${WORKDIR}/00-plugins.conf \
        ${D}${sysconfdir}/NetworkManager/conf.d/00-plugins.conf
}
FILES:${PN} = "${sysconfdir}/NetworkManager/system-connections/ ${sysconfdir}/NetworkManager/conf.d/"
