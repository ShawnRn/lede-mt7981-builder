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

# The MTK private mt_wifi/WARP stack we graft in from the SDK tree is built
# against the 6.6 mediatek target. Keep the LEDE base, but use its 6.6 target.
sed -i 's/^KERNEL_PATCHVER:=.*/KERNEL_PATCHVER:=6.6/' target/linux/mediatek/Makefile

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

perl -0pi -e 's/(define Device\/cudy_tr3000-512mb-v1.*?DEVICE_PACKAGES := )[^\n]*/${1}kmod-usb3 automount kmod-mt_wifi kmod-warp kmod-mediatek_hnat/s' \
  target/linux/mediatek/image/filogic.mk
perl -0pi -e 's/(define Device\/qihoo_360t7.*?DEVICE_PACKAGES := )[^\n]*/${1}kmod-mt_wifi kmod-warp kmod-mediatek_hnat/s' \
  target/linux/mediatek/image/filogic.mk

if [ -f .config ]; then
  config_unset() {
    local sym="$1"
    sed -i -e "/^${sym}=/d" -e "/^# ${sym} is not set/d" .config
    echo "# ${sym} is not set" >> .config
  }

  config_set() {
    local sym="$1"
    local value="$2"
    sed -i -e "/^${sym}=/d" -e "/^# ${sym} is not set/d" .config
    echo "${sym}=${value}" >> .config
  }

  for sym in \
    CONFIG_PACKAGE_luci-app-turboacc \
    CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn \
    CONFIG_PACKAGE_kmod-mt7915e \
    CONFIG_PACKAGE_kmod-mt7981-firmware \
    CONFIG_PACKAGE_mt7981-wo-firmware \
    CONFIG_PACKAGE_wpad-basic-mbedtls; do
    config_unset "$sym"
  done

  config_set CONFIG_KERNEL_WIRELESS_EXT y
  config_set CONFIG_PACKAGE_wireless-tools y
  config_set CONFIG_PACKAGE_kmod-mediatek_hnat y
  config_set CONFIG_PACKAGE_luci-app-turboacc-mtk y
  config_set CONFIG_PACKAGE_luci-i18n-turboacc-mtk-zh-cn y
  config_set CONFIG_PACKAGE_luci-app-mtwifi-cfg y
  config_set CONFIG_PACKAGE_luci-i18n-mtwifi-cfg-zh-cn y
  config_set CONFIG_PACKAGE_mtwifi-cfg y
  config_set CONFIG_PACKAGE_datconf y
  config_set CONFIG_PACKAGE_datconf-lua y
  config_set CONFIG_PACKAGE_kvcedit y
  config_set CONFIG_PACKAGE_libkvcutil y
  config_set CONFIG_PACKAGE_kmod-conninfra y
  config_set CONFIG_MTK_CONNINFRA_APSOC y
  config_set CONFIG_MTK_CONNINFRA_APSOC_MT7981 y
  config_set CONFIG_CONNINFRA_EMI_SUPPORT y
  config_set CONFIG_CONNINFRA_AUTO_UP y
  config_set CONFIG_PACKAGE_kmod-mt_wifi y
  config_set CONFIG_MTK_SUPPORT_OPENWRT y
  config_set CONFIG_MTK_WIFI_DRIVER y
  config_set CONFIG_MTK_FIRST_IF_MT7981 y
  config_set CONFIG_MTK_SECOND_IF_NONE y
  config_set CONFIG_MTK_THIRD_IF_NONE y
  config_set CONFIG_MTK_RT_FIRST_IF_RF_OFFSET 0xc0000
  config_set CONFIG_MTK_MT_WIFI m
  config_set CONFIG_MTK_MT_WIFI_PATH '"mt_wifi"'
  config_set CONFIG_MTK_FIRST_IF_EEPROM_FLASH y
  config_set CONFIG_MTK_RT_FIRST_CARD_EEPROM '"flash"'
  config_set CONFIG_MTK_WIFI_BASIC_FUNC y
  config_set CONFIG_MTK_DOT11_N_SUPPORT y
  config_set CONFIG_MTK_DOT11_VHT_AC y
  config_set CONFIG_MTK_DOT11_HE_AX y
  config_set CONFIG_MTK_CFG_SUPPORT_FALCON_MURU y
  config_set CONFIG_MTK_CFG_SUPPORT_FALCON_TXCMD_DBG y
  config_set CONFIG_MTK_CFG_SUPPORT_FALCON_SR y
  config_set CONFIG_MTK_CFG_SUPPORT_FALCON_PP y
  config_set CONFIG_MTK_WIFI_TWT_SUPPORT y
  config_set CONFIG_MTK_G_BAND_256QAM_SUPPORT y
  config_set CONFIG_MTK_TPC_SUPPORT y
  config_set CONFIG_MTK_ICAP_SUPPORT y
  config_set CONFIG_MTK_SPECTRUM_SUPPORT y
  config_set CONFIG_MTK_BACKGROUND_SCAN_SUPPORT y
  config_set CONFIG_MTK_SMART_CARRIER_SENSE_SUPPORT y
  config_set CONFIG_MTK_SCS_FW_OFFLOAD y
  config_set CONFIG_MTK_MT_DFS_SUPPORT y
  config_set CONFIG_MTK_OFFCHANNEL_SCAN_FEATURE y
  config_set CONFIG_MTK_HDR_TRANS_TX_SUPPORT y
  config_set CONFIG_MTK_HDR_TRANS_RX_SUPPORT y
  config_set CONFIG_MTK_DBDC_MODE y
  config_set CONFIG_MTK_WSC_INCLUDED y
  config_set CONFIG_MTK_WSC_V2_SUPPORT y
  config_set CONFIG_MTK_DOT11W_PMF_SUPPORT y
  config_set CONFIG_MTK_TXBF_SUPPORT y
  config_set CONFIG_MTK_FAST_NAT_SUPPORT y
  config_set CONFIG_MTK_WHNAT_SUPPORT m
  config_set CONFIG_MTK_WARP_V2 y
  config_set CONFIG_MTK_IGMP_SNOOP_SUPPORT y
  config_set CONFIG_MTK_MEMORY_SHRINK y
  config_set CONFIG_MTK_MEMORY_SHRINK_AGGRESS y
  config_set CONFIG_MTK_RTMP_FLASH_SUPPORT y
  config_set CONFIG_MTK_CAL_BIN_FILE_SUPPORT y
  config_set CONFIG_MTK_ATE_SUPPORT y
  config_set CONFIG_MTK_WLAN_SERVICE y
  config_set CONFIG_MTK_MBO_SUPPORT y
  config_set CONFIG_MTK_MAP_SUPPORT y
  config_set CONFIG_MTK_MAP_R2_VER_SUPPORT y
  config_set CONFIG_MTK_MAP_R3_VER_SUPPORT y
  config_set CONFIG_MTK_MAP_R2_6E_SUPPORT y
  config_set CONFIG_MTK_MAP_R3_6E_SUPPORT y
  config_set CONFIG_MTK_UAPSD y
  config_set CONFIG_MTK_RED_SUPPORT y
  config_set CONFIG_MTK_FIRST_IF_IPAILNA y
  config_set CONFIG_MTK_MT7981_NEW_FW y
  config_set CONFIG_MTK_WIFI_FW_BIN_LOAD y
  config_set CONFIG_MTK_WIFI_MODE_AP m
  config_set CONFIG_MTK_MT_AP_SUPPORT m
  config_set CONFIG_MTK_WDS_SUPPORT y
  config_set CONFIG_MTK_MBSS_SUPPORT y
  config_set CONFIG_MTK_APCLI_SUPPORT y
  config_set CONFIG_MTK_MUMIMO_SUPPORT y
  config_set CONFIG_MTK_MU_RA_SUPPORT y
  config_set CONFIG_MTK_DOT11R_FT_SUPPORT y
  config_set CONFIG_MTK_DOT11K_RRM_SUPPORT y
  config_set CONFIG_MTK_MLME_MULTI_QUEUE_SUPPORT y
  config_set CONFIG_MTK_WIFI_EAP_FEATURE y
  config_set CONFIG_MTK_VLAN_SUPPORT y
  config_set CONFIG_MTK_ANTENNA_CONTROL_SUPPORT y
  config_set CONFIG_MTK_MGMT_TXPWR_CTRL y
  config_set CONFIG_MTK_RA_PHY_RATE_SUPPORT y
  config_set CONFIG_MTK_AMPDU_CONF_SUPPORT y
  config_set CONFIG_MTK_ACK_CTS_TIMEOUT_SUPPORT y
  config_set CONFIG_MTK_MBSS_DTIM_SUPPORT y
  config_set CONFIG_MTK_QOS_R1_SUPPORT y
  config_set CONFIG_MTK_CON_WPS_SUPPORT y
  config_set CONFIG_MTK_MCAST_RATE_SPECIFIC y
  config_set CONFIG_MTK_VOW_SUPPORT y
  config_set CONFIG_MTK_WLAN_HOOK y
  config_set CONFIG_MTK_GREENAP_SUPPORT y
  config_set CONFIG_MTK_AIR_MONITOR y
  config_set CONFIG_MTK_WNM_SUPPORT y
  config_set CONFIG_MTK_INTERWORKING y
  config_set CONFIG_MTK_WPA3_SUPPORT y
  config_set CONFIG_MTK_OWE_SUPPORT y
  config_set CONFIG_MTK_WIFI_MT_MAC y
  config_set CONFIG_MTK_MT_MAC y
  config_set CONFIG_MTK_CHIP_MT7981 y
  config_set CONFIG_PACKAGE_kmod-warp y
  config_set CONFIG_WARP_VERSION 2
  config_set CONFIG_WARP_DBG_SUPPORT y
  config_set CONFIG_WED_HW_RRO_SUPPORT y
  config_set CONFIG_WARP_CHIPSET '"mt7981"'
  config_set CONFIG_PACKAGE_wifi-dats y
  config_set CONFIG_first_card y
  config_set CONFIG_first_card_name '"MT7981"'
  config_unset CONFIG_second_card
  config_unset CONFIG_third_card
  config_unset CONFIG_PACKAGE_wifi-profile
fi

mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-shawnwrt-argon <<'EOF'
#!/bin/sh
uci -q batch <<EOT
set luci.main.mediaurlbase='/luci-static/argon'
set luci.themes.Argon='/luci-static/argon'
commit luci
set argon.@global[0]=global
set argon.@global[0].blur='0'
set argon.@global[0].blur_dark='10'
set argon.@global[0].transparency='0.3'
set argon.@global[0].transparency_dark='0.3'
set argon.@global[0].mode='normal'
set argon.@global[0].online_wallpaper='none'
set argon.@global[0].primary='#cec0ab'
set argon.@global[0].dark_primary='#cec0ab'
commit argon
EOT
exit 0
EOF
chmod +x files/etc/uci-defaults/99-shawnwrt-argon

cat > files/etc/uci-defaults/zzzz-shawnwrt-mtk-safe-boot <<'EOF'
#!/bin/sh

# First mtwifi validation images must prefer a reachable wired boot over
# automatic acceleration. The MTK modules are included, but loaded manually
# after SSH login so the failing stage can be identified without serial logs.
for svc in \
  turboacc \
  qmodem_init \
  qmodem_network \
  qmodem_led \
  qmodem_reboot \
  qmodem_usage_stats \
  sms_forwarder \
  ubus-at-daemon; do
  [ -x "/etc/init.d/$svc" ] && "/etc/init.d/$svc" disable >/dev/null 2>&1
done

uci -q set turboacc.config.fastpath='none'
uci -q commit turboacc

exit 0
EOF
chmod +x files/etc/uci-defaults/zzzz-shawnwrt-mtk-safe-boot

mkdir -p files/root
cat > files/root/mtk-driver-test.sh <<'EOF'
#!/bin/sh
set -eu

echo "== ShawnWrt MTK driver staged test =="
echo "Run this from SSH after confirming wired LAN is stable."
echo

load_one() {
	local mod="$1"
	echo "== modprobe $mod =="
	modprobe "$mod"
	sleep 3
	lsmod | grep -E "^${mod}[[:space:]]|^mt_wifi[[:space:]]|^mtk_warp[[:space:]]|^mtkhnat[[:space:]]|^conninfra[[:space:]]" || true
	logread | tail -n 80 || true
	echo
}

load_one conninfra
load_one mt_wifi
load_one mtk_warp_proxy
load_one mtk_warp
load_one mtkhnat

echo "All staged module loads returned. If the router rebooted, the last printed module is the suspect."
EOF
chmod +x files/root/mtk-driver-test.sh
