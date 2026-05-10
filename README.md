# LEDE Firmware Builder

基于 [Lean's LEDE](https://github.com/coolsnowwolf/lede) 源码，通过 GitHub Actions 自动编译 ShawnWrt 固件。

当前仓库已经不只是两台 MT7981 路由器的编译器，也包含通用 x64 和 ARM64 镜像。`main` 分支保持常规 LEDE 驱动路线；`mtwifi-qwrt-performance` 分支用于实验：整体仍使用 LEDE，但把 MTK SDK 系的 `mt_wifi` / WARP / HNAT 栈迁移进来，用于 TR3000 和 360T7 的高性能无线/硬件加速验证。

## 支持目标

| Workflow device | 平台 | 输出目标 | 说明 |
| --- | --- | --- | --- |
| `TR3000-512MB` | MediaTek MT7981B | `cudy_tr3000-512mb-v1` | 适用于已改 512MB NAND/U-Boot 布局的 Cudy TR3000。 |
| `360T7` | MediaTek MT7981B | `qihoo_360t7` | 128MB NAND 的 360T7。 |
| `x64` | x86_64 generic | `x86/64` | 通用 x64 虚拟机或裸机镜像。 |
| `arm64` | ARMv8 generic | `armsr/armv8` | 通用 ARM64 虚拟机/SBC 镜像。 |
| `all` | 混合 | 全部目标 | 展开为 `TR3000-512MB 360T7 x64 arm64`。 |

## 分支说明

- `main`：常规 ShawnWrt LEDE 编译分支，用于正式固件。
- `mtwifi-qwrt-performance`：MTK 闭源驱动实验分支。从 MTK SDK 系源码迁入 `conninfra`、`mt_wifi`、`warp`、`mtk_hnat`、`mtwifi-cfg`、`datconf`、`luci-app-turboacc-mtk`，再补上 Linux 6.6 和 LEDE 需要的兼容修复。

操作一个分支时不要影响其他分支。读日志、取消运行、推送修复、启动 workflow 时，都必须限定到目标分支或明确的 run id。

## 内置能力

- ShawnWrt 首页：`diy-part1.sh` 从 `ShawnRn/shawnwrt-packages` 拉取 `luci-app-shawnwrt-index`，本仓库不维护重复包副本。
- ShawnWrt 品牌：镜像文件名前缀为 `ShawnWrt-...`，并带构建时间戳。
- 默认 LAN IP：`192.168.10.1`。
- 默认主机名：`ShawnWrt`。
- Argon 主题默认值通过 `/etc/uci-defaults/99-shawnwrt-argon` 写入。
- 镜像内写入 ImmortalWrt 24.10.5 opkg feeds，刷机后可以直接使用更丰富的软件源。
- MT7981 路由器配置内置 OpenClash LuCI 插件，但不内置 Clash/mihomo core。
- TR3000、x64、arm64 配置加入 USB 网卡/Modem 支持，包括 RNDIS、CDC Ethernet、iPhone USB 共享网络、CDC NCM、CDC MBIM、Huawei CDC NCM、Realtek RTL815x、ASIX AX88179、Aquantia AQC111、QModem、USB 打印、USB 工具等。
- TR3000 额外包含 USB3、USB 存储、block mount 和常见文件系统支持。
- 按目标选择硬件加速能力：flow offload、FullCone NAT、BBR；在 MTK 实验分支上还包含 MTK HNAT/WARP/mt_wifi。

## GitHub Actions 编译

使用 `LEDE Firmware Builder` workflow。本仓库默认不在本地编译 LEDE/OpenWrt 固件。

手动触发参数：

- `device`：`TR3000-512MB`、`360T7`、`x64`、`arm64` 或 `all`。
- `ssh`：打开临时 tmate menuconfig 会话；`device=all` 时无效。
- `release`：`true` 时发布到 GitHub Releases；`false` 时仅保留为 workflow artifact。

常用命令：

```bash
gh workflow run "LEDE Firmware Builder" \
  --repo ShawnRn/lede-mt7981-builder \
  --ref main \
  -f device=all \
  -f release=true
```

```bash
gh workflow run "LEDE Firmware Builder" \
  --repo ShawnRn/lede-mt7981-builder \
  --ref mtwifi-qwrt-performance \
  -f device=all \
  -f release=false
```

只检查目标分支：

```bash
gh run list \
  --repo ShawnRn/lede-mt7981-builder \
  --branch mtwifi-qwrt-performance \
  --workflow "LEDE Firmware Builder"
```

## 仓库结构

```text
.
├── .github/workflows/
│   └── lede-builder.yml               # GitHub Actions 固件编译 workflow
├── config/
│   ├── 360t7.config                   # 360T7 seed config
│   ├── arm64.config                   # 通用 ARM64 seed config
│   ├── mtwifi-qwrt-performance.config # MTK 闭源驱动附加配置
│   ├── tr3000-512mb.config            # TR3000 512MB seed config
│   └── x64.config                     # 通用 x64 seed config
├── openwrt-mod/
│   ├── cudy-tr3000-512.mk             # TR3000 512MB 自定义 target
│   ├── mt7981b-cudy-tr3000-512mb-v1.dts
│   └── 999-*.patch                    # MTK 兼容/HNAT 修复补丁
├── package/
│   ├── luci-i18n-minieap-zh-cn/
│   ├── luci-proto-minieap/
│   └── minieap-gdufs/
├── diy-part1.sh                       # feeds 更新前自定义和包迁移
├── diy-part2.sh                       # feeds 更新后 target/config/default 调整
└── README.md
```

## 目标注意事项

- TR3000 512MB 镜像只适用于已经切到自定义 512MB NAND/U-Boot 布局的设备。
- 刷机或改 U-Boot 前保留设备自己的 `Factory` 和 `bdinfo` 备份。
- 依赖本次 LEDE kernel ABI 的内核模块应内置进固件；普通用户态包通常可以走 opkg feeds。
- MTK 闭源驱动分支是实验分支。成功的 TR3000 构建应包含 `kmod-mt_wifi`、`kmod-conninfra`、`kmod-warp`、`kmod-mediatek_hnat`、`luci-app-mtwifi-cfg`、`luci-app-turboacc-mtk`、`datconf`、`mtwifi-cfg`。

## 致谢

- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- MTK 实验来源：`padavanonly/immortalwrt-mt798x-6.6`
- QModem feed：`FUjr/QModem`

Maintained by Shawn Rain.
