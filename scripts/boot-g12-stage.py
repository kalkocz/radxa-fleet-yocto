#!/usr/bin/python3
# Radxa Zero (Amlogic G12A / S905Y2) Maskrom USB boot helper.
# Loads U-Boot to RAM via the Amlogic AMLC protocol so the eMMC can be
# exposed with `ums 0 mmc 2` and flashed.
#
# IMPORTANT: feed the COMBINED bl2+tpl image, NOT u-boot.bin.usb.bl2 alone:
#   cat u-boot.bin.usb.bl2 u-boot.bin.usb.tpl > u-boot-usb-combined.bin
# bl2 alone (64KB) fails — BL2 requests AMLC data at offset >=65536 (past its
# end) and epout.write() times out with [Errno 110].
#
# Usage: sudo python3 boot-g12-stage.py /path/to/u-boot-usb-combined.bin
import time, sys
import usb.util
from pyamlboot import pyamlboot

binary = sys.argv[1]
dev = pyamlboot.AmlogicSoC()
socid = dev.identify()
stage = ord(socid[2])
print("ROM: %d.%d Stage: %d.%d" % (ord(socid[0]), ord(socid[1]), ord(socid[2]), ord(socid[3])))

with open(binary, 'rb') as f:
    data = f.read()

if stage == 0:
    print("Stage 0: loading BL2...")
    dev.writeLargeMemory(0xfffa0000, data[0:0x10000], 4096)
    print("Running BL2...")
    dev.run(0xfffa0000)
    print("Waiting for BL2 to re-enumerate...")
    usb.util.dispose_resources(dev.dev)
    del dev
    time.sleep(4)
    print("Re-initializing USB device...")
    dev = pyamlboot.AmlogicSoC()
    socid2 = dev.identify()
    print("Post-BL2 Stage: %d.%d" % (ord(socid2[2]), ord(socid2[3])))
else:
    print("Stage 1: BL2 already running")

seq = 0
prevLength = -1
prevOffset = -1
while True:
    (length, offset) = dev.getBootAMLC()
    if length == prevLength and offset == prevOffset:
        print("[BL2 END]")
        break
    prevLength, prevOffset = length, offset
    print("AMLC dataSize=%d offset=%d seq=%d" % (length, offset, seq))
    dev.writeAMLCData(seq, offset, data[offset:offset+length])
    print("[DONE]")
    seq += 1
print("U-Boot loaded successfully")
