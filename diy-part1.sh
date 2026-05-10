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
# Keep Lean's LEDE as the base tree. For QWRT-like performance testing, graft
# the newer MTK SDK mt_wifi/WARP/conninfra package set from hanwckf's mt798x
# tree, while retaining the Linux 6.6 HNAT/wifi_utility patches from the
# padavanonly 24.10 tree.
MTK_WIFI_REPO="${MTK_WIFI_REPO:-https://github.com/hanwckf/immortalwrt-mt798x.git}"
MTK_WIFI_BRANCH="${MTK_WIFI_BRANCH:-openwrt-21.02}"
MTK_HNAT_REPO="${MTK_HNAT_REPO:-https://github.com/padavanonly/immortalwrt-mt798x-6.6.git}"
MTK_HNAT_BRANCH="${MTK_HNAT_BRANCH:-openwrt-24.10-6.6}"
MTK_WIFI_TMP="$(mktemp -d)"
MTK_HNAT_TMP="$(mktemp -d)"

cleanup_mtk() { rm -rf "$MTK_WIFI_TMP" "$MTK_HNAT_TMP"; }
trap 'cleanup_pkg; cleanup_mtk' EXIT

git clone -q --depth 1 --filter=blob:none -b "$MTK_WIFI_BRANCH" "$MTK_WIFI_REPO" "$MTK_WIFI_TMP"
git clone -q --depth 1 --filter=blob:none -b "$MTK_HNAT_BRANCH" "$MTK_HNAT_REPO" "$MTK_HNAT_TMP"

mkdir -p package/mtk/drivers package/mtk/applications
for pkg in conninfra mt_wifi warp wifi-profile; do
  rm -rf "package/mtk/drivers/$pkg"
  cp -r "$MTK_WIFI_TMP/package/mtk/drivers/$pkg" "package/mtk/drivers/$pkg"
done

# Keep the experimental MTK kernel modules installable, but do not let the
# image autoload them during early boot. The first TR3000 test image bootlooped
# before persistent logs were available, so staged manual loading is safer:
#   modprobe conninfra
#   modprobe mt_wifi
#   modprobe mtk_warp_proxy
#   modprobe mtk_warp
#   modprobe mtkhnat
sed -i '/AUTOLOAD:=.*conninfra/d' package/mtk/drivers/conninfra/Makefile
sed -i '/AUTOLOAD:=.*mt_wifi/d;/AUTOLOAD:=.*mtk_warp_proxy/d;/AutoProbe,mt_wifi/d' \
  package/mtk/drivers/mt_wifi/Makefile
sed -i '/AUTOLOAD:=.*mtk_warp/d' package/mtk/drivers/warp/Makefile

# The vendor mt_wifi Makefiles force pre-cal/RLM flags even when the MT7981
# config disables them. Those flags reference calibration macros that are not
# present in this source tree, so keep them controlled by Kconfig.
for mf in \
  package/mtk/drivers/mt_wifi/src/mt_wifi_ap/Makefile \
  package/mtk/drivers/mt_wifi/src/mt_wifi/os/linux/Makefile.mt_wifi_ap \
  package/mtk/drivers/mt_wifi/src/mt_wifi/os/linux/Makefile.mt_wifi_ap_alps; do
  [ -f "$mf" ] || continue
  sed -i \
    -e '/^EXTRA_CFLAGS += -DPRE_CAL_TRX_SET1_SUPPORT$/d' \
    -e '/^EXTRA_CFLAGS += -DRLM_CAL_CACHE_SUPPORT$/d' \
    -e '/^EXTRA_CFLAGS += -DPRE_CAL_TRX_SET2_SUPPORT$/d' \
    "$mf"
done

# Linux 6.x removed netif_rx_ni(); the driver only needs to pass the skb into
# the receive path here, so use netif_rx() consistently.
grep -RIl 'netif_rx_ni' package/mtk/drivers/mt_wifi/src/mt_wifi | \
  xargs -r sed -i 's/netif_rx_ni(/netif_rx(/g'

for pkg in datconf mtwifi-cfg luci-app-mtwifi-cfg luci-app-turboacc-mtk; do
  rm -rf "package/mtk/applications/$pkg"
  cp -r "$MTK_WIFI_TMP/package/mtk/applications/$pkg" "package/mtk/applications/$pkg"
done

# The MTK package Makefiles reference local-only source archives without
# upstream URLs. Copy the matching vendor archives into dl/ so Actions builds
# remain deterministic.
mkdir -p dl
find "$MTK_WIFI_TMP/dl" -maxdepth 1 -type f \( \
  -name 'datconf-*.tar.*' -o \
  -name 'mt79xx_*.tar.*' -o \
  -name 'mt79xx_conninfra_*.tar.*' -o \
  -name 'warp_*.tar.*' \
\) -exec cp {} dl/ \;

rm -rf package/lean/mt

mkdir -p \
  target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek \
  target/linux/mediatek/files-6.6/drivers/net/wireless \
  target/linux/mediatek/files-6.6/include/net \
  target/linux/mediatek/files-6.6/include/linux \
  target/linux/mediatek/files-6.6/include/uapi/linux

rm -rf target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat
cp -r "$MTK_HNAT_TMP/target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_hnat" \
  target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/
cp "$MTK_HNAT_TMP/target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_eth_reset.h" \
  target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/
rm -rf target/linux/mediatek/files-6.6/drivers/net/wireless/wifi_utility
cp -r "$MTK_HNAT_TMP/target/linux/mediatek/files-6.6/drivers/net/wireless/wifi_utility" \
  target/linux/mediatek/files-6.6/drivers/net/wireless/
cp "$MTK_HNAT_TMP/target/linux/mediatek/files-6.6/include/net/ra_nat.h" \
  target/linux/mediatek/files-6.6/include/net/
cp "$MTK_HNAT_TMP/target/linux/mediatek/files-6.6/include/linux/wireless.h" \
  target/linux/mediatek/files-6.6/include/linux/
rm -rf target/linux/mediatek/files-6.6/include/uapi/linux/wapp
cp -r "$MTK_HNAT_TMP/target/linux/mediatek/files-6.6/include/uapi/linux/wapp" \
  target/linux/mediatek/files-6.6/include/uapi/linux/

mkdir -p target/linux/mediatek/patches-6.6
for patch in \
  0101-add-mtk-wifi-utility-rbus.patch \
  999-2735-netfilter-nf_flow_table-support-hw-offload-through-v.patch \
  999-2736-net-8021q-support-hardware-flow-table-offload.patch \
  999-2737-net-bridge-support-hardware-flow-table-offload.patch \
  999-2738-net-pppoe-support-hardware-flow-table-offload.patch \
  999-2739-net-dsa-support-hardware-flow-table-offload.patch \
  999-2740-net-macvlan-support-hardware-flow-table-offload.patch \
  999-2741-mtkhnat-add-support-for-virtual-interface-a.patch \
  999-2742-mtkhnat-tnl-interface-offload-check.patch.patch \
  999-2904-mtk-flow-hw-path-add-skb-hash.patch \
  999-2905-mtk-nf-conn-counter-add-diff-stats.patch \
  999-2906-mtk-hnat-drop-unsupported-rxd-accessors.patch \
  999-2907-mtk-hnat-export-ppd-bridge-symbols.patch \
  999-2745-mtkhnat-add-mtkhnat-driver-support.patch \
  999-2743-mtkhnat-ipv6-fix-pskb-expand-head-limitatio.patch \
  999-3002-net-ethernet-mtk_ppe-keep-sp-in-the-info1.patch \
  999-3007-net-ethernet-mtk_ppe-add-roaming-handler.patch; do
  if [[ "$patch" == "999-29"* ]] || [[ "$patch" == "999-3007"* ]]; then
    cp "$GITHUB_WORKSPACE/openwrt-mod/$patch" "target/linux/mediatek/patches-6.6/$patch"
  else
    cp "$MTK_HNAT_TMP/target/linux/mediatek/patches-6.6/$patch" "target/linux/mediatek/patches-6.6/$patch"
  fi
done

if ! grep -q 'define KernelPackage/mediatek_hnat' package/kernel/linux/modules/netdevices.mk; then
  cat >> package/kernel/linux/modules/netdevices.mk <<'EOF'

define KernelPackage/mediatek_hnat
  SUBMENU:=$(NETWORK_DEVICES_MENU)
  TITLE:=Mediatek HNAT module
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

if ! grep -q '^CONFIG_WIRELESS_EXT=y' target/linux/mediatek/filogic/config-6.6; then
  cat >> target/linux/mediatek/filogic/config-6.6 <<'EOF'
CONFIG_WIRELESS_EXT=y
CONFIG_WEXT_CORE=y
CONFIG_WEXT_PROC=y
CONFIG_WEXT_PRIV=y
CONFIG_WEXT_SPY=y
EOF
fi

# Add additional LuCI feed (openwrt-25.12 branch)
if ! grep -q '^src-git luci_25 ' feeds.conf.default; then
  echo "src-git luci_25 https://github.com/openwrt/luci.git;openwrt-25.12" >> feeds.conf.default
fi

# Add QModem feed for USB/5G modem management packages selected by the seed
# configs. Keeping it as a feed avoids vendoring another package tree here.
if ! grep -q '^src-git qmodem ' feeds.conf.default; then
  echo "src-git qmodem https://github.com/FUjr/QModem.git;main" >> feeds.conf.default
fi
