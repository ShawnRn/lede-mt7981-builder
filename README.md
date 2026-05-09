# LEDE Firmware Builder

基于 [Lean's LEDE](https://github.com/coolsnowwolf/lede) 源码，为以下两台设备自动编译固件：

| 设备 | SoC | 闪存 | 目标 |
|------|-----|------|------|
| Cudy TR3000 | MT7981B | 512MB NAND (改版 U-Boot) | `cudy_tr3000-512mb-v1` |
| Qihoo 360T7 | MT7981B | 128MB NAND | `qihoo_360t7` |

## ⚡ 硬件加速

本固件已启用全部硬件加速特性，确保最优性能：

- **MTK HNAT** — MediaTek 硬件 NAT 加速
- **Flow Offloading** — nftables 流量卸载
- **FullCone NAT** — 全锥形 NAT
- **TurboACC** — Lean 的综合网络加速
- **TCP BBR** — Google BBR 拥塞控制算法

## 📅 自动编译

- **每周定时编译**：北京时间每周一 04:00 自动拉取最新 LEDE 源码编译
- **手动触发**：支持在 Actions 页面手动选择设备编译
- **SSH Menuconfig**：可通过 tmate 远程调整 `.config`

## 🚀 使用方法

### 下载固件

前往 [Releases](../../releases) 页面下载最新编译的 sysupgrade 固件。

### 手动触发编译

1. 进入 **Actions** 页面
2. 选择 **LEDE Firmware Builder** 工作流
3. 点击 **Run workflow**
4. 选择设备型号（或 `all` 编译全部）

## 📁 仓库结构

```
.
├── .github/workflows/
│   └── lede-builder.yml      # GitHub Actions 工作流
├── config/
│   ├── tr3000-512mb.config    # TR3000 512MB 设备配置 (seed)
│   └── 360t7.config           # 360T7 设备配置 (seed)
├── openwrt-mod/
│   ├── cudy-tr3000-512.mk     # TR3000 512MB 自定义 target
│   └── mt7981b-cudy-tr3000-512mb-v1.dts  # 512MB NAND DTS
├── diy-part1.sh               # feeds 更新前自定义脚本
├── diy-part2.sh               # feeds 更新后自定义脚本
└── README.md
```

## ⚠️ 注意事项

- 本仓库只内置 ShawnWrt Packages 里的 `luci-app-shawnwrt-index` 作为主页，其余 ShawnWrt 插件仍不内置
- TR3000 512MB 固件仅适用于已改版 U-Boot 的 512MB NAND 设备
- 默认密码：`password`
- 默认 IP：`192.168.1.1`

## 致谢

- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) — Lean's LEDE 源码
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) — GitHub Actions 编译方案

---

**Maintained by Shawn Rain**
