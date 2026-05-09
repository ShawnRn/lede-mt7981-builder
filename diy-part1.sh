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

# Add additional LuCI feed (openwrt-25.12 branch)
echo "src-git luci_25 https://github.com/openwrt/luci.git;openwrt-25.12" >> feeds.conf.default
