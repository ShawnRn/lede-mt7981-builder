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

# Add build timestamp to output file names and use ShawnWrt branding.
sed -i -e '/^BUILD_TIMESTAMP :=/d' \
       -e '/^IMG_PREFIX:=/i BUILD_TIMESTAMP := $(shell date +%Y%m%d-%H%M)' \
       -e 's|^IMG_PREFIX:=.*|IMG_PREFIX:=ShawnWrt-$(BOARD)$(if $(SUBTARGET),-$(SUBTARGET))-$(BUILD_TIMESTAMP)|' \
       include/image.mk

# ── Add the dedicated TR3000 512MB target ──
# This adds a custom device definition and DTS for the 512MB NAND TR3000,
# which has a much larger UBI partition (~490MB) than the stock mod target.
MOD_ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"
cat "$MOD_ROOT/openwrt-mod/cudy-tr3000-512.mk" >> \
  target/linux/mediatek/image/filogic.mk
cp "$MOD_ROOT/openwrt-mod/mt7981b-cudy-tr3000-512mb-v1.dts" \
  target/linux/mediatek/dts/

# Keep flashed images on rich, browser-free package indexes. Kernel modules
# still need to be built into the image because this LEDE build has its own ABI.
mkdir -p files/etc/opkg
cat > files/etc/opkg/distfeeds.conf <<'EOF'
src/gz immortalwrt_core https://downloads.immortalwrt.org/releases/24.10.5/targets/mediatek/filogic/packages
src/gz immortalwrt_base https://downloads.immortalwrt.org/releases/24.10.5/packages/aarch64_cortex-a53/base
src/gz immortalwrt_luci https://downloads.immortalwrt.org/releases/24.10.5/packages/aarch64_cortex-a53/luci
src/gz immortalwrt_packages https://downloads.immortalwrt.org/releases/24.10.5/packages/aarch64_cortex-a53/packages
src/gz immortalwrt_routing https://downloads.immortalwrt.org/releases/24.10.5/packages/aarch64_cortex-a53/routing
src/gz immortalwrt_telephony https://downloads.immortalwrt.org/releases/24.10.5/packages/aarch64_cortex-a53/telephony
EOF
: > files/etc/opkg/customfeeds.conf

mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-shawnwrt-argon <<'EOF'
#!/bin/sh
uci -q batch <<EOT
set luci.main.mediaurlbase='/luci-static/argon'
commit luci
EOT
exit 0
EOF
chmod +x files/etc/uci-defaults/99-shawnwrt-argon
