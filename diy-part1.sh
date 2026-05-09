#!/bin/bash
#
# File name: diy-part1.sh
# Description: LEDE DIY script part 1 (Before Update feeds)
#
# Maintained by Shawn Rain.
# This is free software, licensed under the MIT License.
#
set -euo pipefail

# ── ShawnWrt homepage ──
# Keep the LEDE build lean, but embed the canonical ShawnWrt Index package
# from ShawnWrt Packages instead of maintaining a duplicate copy here.
PKG_REPO="https://github.com/ShawnRn/shawnwrt-packages.git"
PKG_BRANCH="main"
PKG_TMP="$(mktemp -d)"

cleanup_pkg() { rm -rf "$PKG_TMP"; }
trap cleanup_pkg EXIT

git clone -q --depth 1 -b "$PKG_BRANCH" "$PKG_REPO" "$PKG_TMP"

if [ -d "$PKG_TMP/openwrt/luci-app-shawnwrt-index" ]; then
  mkdir -p package
  rm -rf package/luci-app-shawnwrt-index
  cp -r "$PKG_TMP/openwrt/luci-app-shawnwrt-index" package/
fi

# ── Firmware-local packages ──
# These are firmware-specific and maintained only in the firmware repo.
for pkg in \
  luci-i18n-minieap-zh-cn \
  luci-proto-minieap \
  minieap-gdufs; do
  if [ -d "$GITHUB_WORKSPACE/package/$pkg" ]; then
    mkdir -p package
    rm -rf "package/$pkg"
    cp -r "$GITHUB_WORKSPACE/package/$pkg" package/
  fi
done

# ── MTK private Wi-Fi driver experiment ──
# Keep Lean's LEDE as the base tree, but graft the MT7981 mt_wifi/WARP/HNAT
# stack from the MTK SDK-based tree for the mtwifi-qwrt-performance branch.
MTK_REPO="${MTK_REPO:-https://github.com/padavanonly/immortalwrt-mt798x-6.6.git}"
MTK_BRANCH="${MTK_BRANCH:-openwrt-24.10-6.6}"
MTK_TMP="$(mktemp -d)"

cleanup_mtk() { rm -rf "$MTK_TMP"; }
trap 'cleanup_pkg; cleanup_mtk' EXIT

git clone -q --depth 1 --filter=blob:none -b "$MTK_BRANCH" "$MTK_REPO" "$MTK_TMP"

mkdir -p package/mtk/drivers package/mtk/applications
for pkg in conninfra mt_wifi warp wifi-profile; do
  rm -rf "package/mtk/drivers/$pkg"
  cp -r "$MTK_TMP/package/mtk/drivers/$pkg" "package/mtk/drivers/$pkg"
done

for pkg in datconf mtwifi-cfg luci-app-mtwifi-cfg luci-app-turboacc-mtk; do
  rm -rf "package/mtk/applications/$pkg"
  cp -r "$MTK_TMP/package/mtk/applications/$pkg" "package/mtk/applications/$pkg"
done

rm -rf package/lean/mt

mkdir -p \
  target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek \
  target/linux/mediatek/files-6.6/drivers/net/wireless \
  target/linux/mediatek/files-6.6/include/net \
  target/linux/mediatek/files-6.6/include/linux \
  target/linux/mediatek/files-6.6/include/uapi/linux

rm -rf target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat
cp -r "$MTK_TMP/target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat" \
  target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/
rm -rf target/linux/mediatek/files-6.6/drivers/net/wireless/wifi_utility
cp -r "$MTK_TMP/target/linux/mediatek/files-6.6/drivers/net/wireless/wifi_utility" \
  target/linux/mediatek/files-6.6/drivers/net/wireless/
cp "$MTK_TMP/target/linux/mediatek/files-6.6/include/net/ra_nat.h" \
  target/linux/mediatek/files-6.6/include/net/
cp "$MTK_TMP/target/linux/mediatek/files-6.6/include/linux/wireless.h" \
  target/linux/mediatek/files-6.6/include/linux/
rm -rf target/linux/mediatek/files-6.6/include/uapi/linux/wapp
cp -r "$MTK_TMP/target/linux/mediatek/files-6.6/include/uapi/linux/wapp" \
  target/linux/mediatek/files-6.6/include/uapi/linux/

mkdir -p target/linux/mediatek/patches-6.6
for patch in \
  999-2745-mtkhnat-add-mtkhnat-driver-support.patch \
  999-2743-mtkhnat-ipv6-fix-pskb-expand-head-limitatio.patch \
  999-3007-net-ethernet-mtk_ppe-add-roaming-handler.patch \
  999-3008-fix-hnat-header.patch; do
  if [[ "$patch" == "999-3007"* ]] || [[ "$patch" == "999-3008"* ]]; then
    cp "$GITHUB_WORKSPACE/openwrt-mod/$patch" "target/linux/mediatek/patches-6.6/$patch"
  else
    cp "$MTK_TMP/target/linux/mediatek/patches-6.6/$patch" "target/linux/mediatek/patches-6.6/$patch"
  fi
done

if ! grep -q 'define KernelPackage/mediatek_hnat' package/kernel/linux/modules/netdevices.mk; then
  cat >> package/kernel/linux/modules/netdevices.mk <<'EOF'

define KernelPackage/mediatek_hnat
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Mediatek HNAT module
  AUTOLOAD:=$(call AutoLoad,20,mtkhnat)
  DEPENDS:=@TARGET_mediatek +kmod-nf-conntrack +wireless-tools
  KCONFIG:= \
	CONFIG_BRIDGE_NETFILTER=y \
	CONFIG_NETFILTER_FAMILY_BRIDGE=y \
	CONFIG_NET_MEDIATEK_HNAT
  FILES:= \
        $(LINUX_DIR)/drivers/net/ethernet/mediatek/mtk_hnat/mtkhnat.ko
endef

define KernelPackage/mediatek_hnat/description
  Kernel modules for MediaTek HW NAT offloading
endef

$(eval $(call KernelPackage,mediatek_hnat))
EOF
fi

if ! grep -q '^CONFIG_MEDIATEK_NETSYS_V2=y' target/linux/mediatek/filogic/config-6.6; then
  cat >> target/linux/mediatek/filogic/config-6.6 <<'EOF'
CONFIG_MEDIATEK_NETSYS_V2=y
# CONFIG_MEDIATEK_NETSYS_V3 is not set
EOF
fi

# Add additional LuCI feed (openwrt-25.12 branch)
echo "src-git luci_25 https://github.com/openwrt/luci.git;openwrt-25.12" >> feeds.conf.default
