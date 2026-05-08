#!/bin/bash
#
# File name: diy-part1.sh
# Description: LEDE DIY script part 1 (Before Update feeds)
#
# Maintained by Shawn Rain.
# This is free software, licensed under the MIT License.
#
set -euo pipefail

# ── No ShawnWrt packages ──
# This LEDE build is a clean, performance-focused firmware.
# No external package repos are cloned here.

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
