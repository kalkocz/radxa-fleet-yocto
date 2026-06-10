inherit bundle

SUMMARY = "HMS Victory Radxa Zero Fleet RAUC Bundle"

RAUC_BUNDLE_COMPATIBLE = "radxa-zero-ruview"
RAUC_BUNDLE_FORMAT = "plain"
RAUC_KEY_FILE = "/opt/yocto/radxa-fleet/rauc-keys/development-1.key.pem"
RAUC_CERT_FILE = "/opt/yocto/radxa-fleet/rauc-keys/development-1.cert.pem"

RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_SLOT_rootfs = "core-image-minimal"
RAUC_SLOT_rootfs[fstype] = "ext4"
RAUC_SLOT_rootfs[type] = "image"
