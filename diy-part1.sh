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

# Uncomment helloworld feed if you need SSR-Plus
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default
