#!/bin/bash
#
# File name: diy-part2.sh
# Description: LEDE DIY script part 2 (After Update feeds)
#
# Maintained by Shawn Rain.
# This is free software, licensed under the MIT License.
#

# Modify default IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# Modify default hostname
sed -i 's/OpenWrt/ShawnWrt/g' package/base-files/files/bin/config_generate

# Add build date to output file name
sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' \
       -e 's/IMG_PREFIX:=openwrt/IMG_PREFIX:=shawnwrt-lede/g' include/image.mk

# ── Add the dedicated TR3000 512MB target ──
# This adds a custom device definition and DTS for the 512MB NAND TR3000,
# which has a much larger UBI partition (~490MB) than the stock mod target.
MOD_ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"
cat "$MOD_ROOT/openwrt-mod/cudy-tr3000-512.mk" >> \
  target/linux/mediatek/image/filogic.mk
cp "$MOD_ROOT/openwrt-mod/mt7981b-cudy-tr3000-512mb-v1.dts" \
  target/linux/mediatek/dts/
