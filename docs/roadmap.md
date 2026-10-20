# Gru 移植 Android 16

第一台机器是正在运行 postmarketOS 的 Google Scarlet（Acer Chromebook Tab 10）。目标是让它用原厂 depthcharge，从 SD 卡进入 Android 16，内置 eMMC 上的 postmarketOS 留作退路。同一套 FIT 以后可以带上 Gru 家族的其它板。

Android 17 是这套板级工作做完之后的换源码，不和第一台机器的启动并行。

## 结论

沿用 postmarketOS 已经跑通的 `linux-postmarketos-rockchip` 6.6.34，以及 depthcharge 从外置盘启动。图形走 `rockchip-drm`、Mesa Panfrost 和 `drm_hwcomposer`。无线走已经在用的 `ath10k_pci`。

不刷 UEFI，不替换只读固件，不换 6.12 或更新的内核。亮屏和日常功能完成之前不写 eMMC。

已经同步的源码是 `/run/media/alpha/YMTC/lineage-23.2`（LineageOS 23.2，Android 16）。`third_party/android_device_google_trogdor-lineage-24` 是别人做完的 Trogdor 设备树，拿来当产品形态的样板。`third_party/failed_docs` 是这棵 23.2 树上 Trogdor 停在亮屏前的记录，拿来当启动阶段的故障清单。

## 这台机器

2026-10-18 从 `user@10.0.0.133` 只读采集。当时从内置盘启动，没有刷写。发行版是 postmarketOS v25.06，不是 25.04。

| 项 | 实测 |
| --- | --- |
| 型号 | Google Scarlet，`google,scarlet-rev15-sku7`，底板 `google,gru` |
| 机型 | Acer Chromebook Tab 10 |
| SoC | Rockchip RK3399。4× Cortex-A53 600–1512 MHz，2× Cortex-A72 816–2016 MHz |
| GPU | `rockchip,rk3399-mali` / `arm,mali-t860`。显示是 `rockchip-drm`，加速是 Panfrost（`panfrost` 模块，`renderD128`） |
| 内存 | `MemTotal` 3,894,400 kB。zram 1.9 GiB，采集时未使用 |
| 内置盘 | `mmcblk1`，约 29.1 GiB，运行中的根分区 |
| 外置盘 | `mmcblk0`，名 `SD64G`，约 58.3 GiB。采集时没有挂载 |
| 面板 | `kingdisplay,kd097d04`，DSI-1 已连接，模式 `1536x2048`。对应 `/boot/rk3399-gru-scarlet-kd.dtb` |
| 背光 | `/sys/class/backlight/backlight`，raw，采集时 2713/4095 |
| 触摸 | Elan `elan,ekth3500`，I2C `ff130000` 地址 `0x10` |
| 手写笔 | Wacom HID-over-I2C `2D1F:0036`，I2C 地址 `0x09` |
| 音频 | 声卡 `rk3399-gru-sound`：DA7219、MAX98357A、DMIC。UCM 配置已安装 |
| Wi-Fi | `ath10k_pci`，PCI `168c:003e`，子系统 `11ad:0513`（QCA6174）。`wlan0` 已存在 |
| 蓝牙 | `btusb`，USB `0cf3:e300`。`hci0` 已起来，rfkill 未屏蔽 |
| 电池 / 充电 | `sbs-battery` `sbs-9-000b`，采集时 99%、Charging。充电器 `cros_usbpd_charger` |
| 传感器 | `cros-ec-accel`、`cros-ec-gyro` |
| EC | `cros_ec`，STM32F09x。固件 `scarlet_v1.1.7878-f57c60917`，2018-12-14 |
| 安全芯片 | `google,cr50`，`/sys/class/tpm/tpm0`，TPM 2.0。只服务引导 |
| 视频解码 | `hantro_vpu`、`rockchip_vdec` 已加载 |
| 摄像头节点 | 设备树里有 `ovti,ov5695` 和 `ovti,ov2685`。不在完成标准里 |

引导是 ChromeOS depthcharge。正在运行的命令行：

```text
cros_secure kern_guid=2768cb50-0033-274c-b04b-a3faaa3a401a quiet loglevel=2 pmos_boot_uuid=18b08ea7-8422-4ef2-9eb7-29d282a28c74 pmos_root_uuid=8620915a-21bc-452c-9741-f64bdd894604 pmos_rootfsopts=defaults
```

根分区是 `mmcblk1p3`。控制台在设备树里是 `serial2:115200n8`。`deviceinfo` 写着 `deviceinfo_depthcharge_board=gru`，压缩 lzma，内核分区从扇区 8192 起、长 65536 扇区（32 MiB）。`/boot` 里有 `vmlinuz.kpart`，以及 `rk3399-gru-scarlet-kd.dtb`、`scarlet-inx`、`scarlet-dumo`、`kevin`、`bob`。

内置盘分区：

| 分区 | 扇区数 | 名称 | 内容 |
| --- | --- | --- | --- |
| mmcblk1p1 | 65536（32 MiB） | `pmOS_kernel` | depthcharge 内核分区 |
| mmcblk1p2 | 524288（256 MiB） | `pmOS_boot` | `/boot` |
| mmcblk1p3 | 60473311 | `pmOS_root` | ext4，`/` |

外置盘分区名和内置盘不同，也不是这次启动的盘：

| 分区 | 扇区数 | 名称 | 采集时能看到的内容 |
| --- | --- | --- | --- |
| mmcblk0p1 | 65536（32 MiB） | `KernelA` | 没有文件系统 |
| mmcblk0p2 | 65536（32 MiB） | `KernelB` | 没有文件系统 |
| mmcblk0p3 | 1048576（512 MiB） |  | ext4，标签 `bootpart` |
| mmcblk0p4 | 120977408 |  | btrfs，标签 `rootpart` |

这张卡上是另一套系统，不是内置盘的副本。覆写之前先记下它是什么。eMMC 保持不动。

内核包是 `linux-postmarketos-rockchip-6.6.34-r6`。`uname` 为 `6.6.34 #7-postmarketos-rockchip`。Mesa 是 25.1.9。设备包是 `device-google-gru-8-r2`。休眠入口公布了 `deep`（当前选中）和 `s2idle`。`/sys/class/watchdog/watchdog0` 绑在 `dw_wdt` 上，systemd 的 `RuntimeWatchdogSec` 仍是关闭，没有 `90-gru-watchdog.conf`。这台 6.6 上一旦尝试休眠，整机会崩溃，下次启动直接停在 bootloader。

已经从 `/proc/config.gz` 读到、和后面直接相关的配置：

| 项 | 状态 |
| --- | --- |
| `CONFIG_ANDROID_BINDER_IPC` | 编进内核，设备节点 `binder,hwbinder,vndbinder` |
| `CONFIG_ANDROID_BINDERFS` | 关闭 |
| `CONFIG_EXT4_FS`、`CONFIG_F2FS_FS`、`CONFIG_FS_ENCRYPTION` | 编进内核 |
| `CONFIG_EROFS_FS` | 关闭 |
| `CONFIG_SECURITY` | 打开 |
| `CONFIG_SECURITYFS`、`CONFIG_SECURITY_SELINUX`、`CONFIG_SECURITY_NETWORK`、`CONFIG_SECURITY_APPARMOR` | 关闭。这棵内核里没有 SELinux |
| `CONFIG_BPF`、`CONFIG_PSI`、`CONFIG_CPUSETS`、`CONFIG_CGROUPS` | 打开。6.6 的 cpuset 还没有 6.12 那种单独的 `CPUSETS_V1` 开关 |
| `CONFIG_USB_DWC3` | 编进内核 |
| `CONFIG_USB_CONFIGFS` | 模块，`CONFIG_USB_CONFIGFS_F_FS` 关闭 |
| `CONFIG_BLK_DEV_DM`、`CONFIG_DM_CRYPT`、`CONFIG_NFTABLES` | 模块 |
| `CONFIG_DRM_ROCKCHIP` | 编进内核 |
| `CONFIG_DRM_PANFROST` | 模块 |
| `CONFIG_IKCONFIG_PROC` | 打开 |

## Trogdor 的经验能沿用多少

两台机器共用的是 ChromeOS 平板的启动方式，以及 Android 在主线内核上的用户空间骨架。芯片、GPU、无线、音频、分区尺寸都要重做。

### 整段沿用

这些是方法，不依赖高通。

- 外置盘做试验，内置盘留着现在的 postmarketOS。depthcharge 的选盘菜单是退路。完成标准里始终包含「再选内置盘还能进桌面」和「eMMC 内核分区校验和不变」。
- 内核分区是带 ChromeOS 头的 FIT，不是 `boot.img`。板名用这台机器已经在用的 `gru`，压缩先用已经能启动的 lzma。`depthchargectl` 会加上 `kern_guid=%U`。一张 FIT 里放多块 DTB，固件按板号选择。第一块要选中的是 `rk3399-gru-scarlet-kd.dtb`。
- 命令行保留 `console=tty0`，这样面板上能看到早期日志。不写 `root=` 或 `pmos_root_uuid`，除非这一步故意要挂 postmarketOS。
- 内核从 postmarketOS 已经验证过的那一版源码和配置往上加 Android 选项，不换版本。本地版本字符串用来和发行版内核区分。
- 设备树继承 LineageOS 的 mainline 公共部分，本仓库只放 Gru 的板级差异。AOSP 树放在仓库外面。
- 4 GB 内存：默认镜像不带 GApps，打开 zram。
- cr50 只服务引导。Android 密钥用软件 KeyMint 和软件 Gatekeeper。
- bringup 期间 SELinux permissive。传感器走 Chrome EC 的 IIO，Trogdor 那份 subhal 的结构可以改挂载矩阵后使用。
- 健康、灯、电源用 AIDL 示例 HAL 接到 `sbs-battery`、背光和 `cros_usbpd_charger`。Wi-Fi 用 `nl80211` 的 `wpa_supplicant`，不用高通 Android WLAN HAL。
- 固件文件先核对许可证，放未压缩的副本。Alpine 上的 `.zst` 不能直接给 Android 的 firmware loader。

做完的 Trogdor 设备树还提供了可以照着抄的产品形态：Treble、动态分区、erofs 的 system/vendor、f2fs 的 userdata、metadata、`drm_hwcomposer`、minigbm、AIDL 音频、软件 KeyMint。Scarlet 的 makefile 按这个骨架写，把里面的高通项换成下面的板级项。

### 启动阶段要提前做掉的事

`failed_docs` 里 Trogdor 停在亮屏前。那些故障和芯片无关，Gru 的第一份镜像里就要避开。

| 当时的故障 | Gru 上对应的做法 |
| --- | --- |
| 内核默认 LSM 不是 SELinux，`selinuxfs` 挂载 EINVAL | 这棵 6.6 更靠前：SELinux 和 `securityfs` 都没编进去。阶段 2 打开 `CONFIG_SECURITY_NETWORK`、`CONFIG_SECURITY_SELINUX`、`CONFIG_SECURITYFS`，命令行再给 `security=selinux` |
| `ext4` 是模块，first stage 没加载 | Gru 的 ext4 和 f2fs 已经编进内核。若改用 erofs 或 device-mapper，对应模块必须在 first stage 挂分区之前加载 |
| cgroup v1 的 cpuset 返回 EINVAL | 6.6 还没有 `CONFIG_CPUSETS_V1` 这个开关。阶段 3 仍要看 cpuset 是否挂得上，不要提前打 6.12 的补丁 |
| 没有 `/vendor/etc/vintf/manifest.xml`，APEX 里的 KeyMint 进不了清单 | 第一份镜像就带 device manifest |
| `keystore2` 带 `critical`，崩溃四次就重启进选盘菜单 | 清单里的软件 KeyMint 要在它启动前可用 |
| userdata 等 vold，`/data` 只读，APEX 解压和 bpfloader 失败 | userdata 能在 first stage 挂上，并且可写 |
| netfilter 是模块，`netd` 起不来并把 zygote 拉进循环 | 阶段 2 起就把 netd 需要的表编进内核或放进 early-init 的模块列表 |
| HIDL composer 的 `max-level` 低于 target-level，`hwservicemanager` 退出 | 图形用 AIDL 的 `drm_hwcomposer`。不把 `drmfb-composer` 当作目标路径 |
| `device/mainline/common` 的命令行带 `binder.impl=rust` | 6.6 没有 Rust binder。继续用已经编进内核的 C binder，命令行不写这一项 |
| `adb` 依赖 USB functionfs | `CONFIG_USB_CONFIGFS_F_FS` 现在是关闭的。DWC3 已经编进内核，把 functionfs 打开 |

### 必须按 Scarlet 重做

| 层 | Trogdor | 这台 Scarlet |
| --- | --- | --- |
| SoC / 内核 | SC7180，`linux-postmarketos-qcom-sc7180` 6.12.35 | RK3399，`linux-postmarketos-rockchip` 6.6.34 |
| DTB | `sc7180-trogdor-quackingstick-r0.dtb` | `rk3399-gru-scarlet-kd.dtb` |
| depthcharge 板名 | `qc7180` | `gru` |
| 内核分区 | 128 MiB | 当前布局 32 MiB。bringup 的 FIT 按这个尺寸装；装不下时只加大 SD 上的内核分区 |
| GPU | Adreno，Mesa Freedreno / Turnip，固件 `a630_sqe.fw` | Mali-T860，Mesa Panfrost，GLES。不打开 Vulkan，也不找 Adreno 固件 |
| gralloc | `minigbm` platform `msm` | `minigbm` 用 Rockchip / Panfrost 那个 platform |
| 显示 | `1200x1920`，密度 160 | `1536x2048`，约 264 ppi，密度按 260 起 |
| 无线 | `ath10k_snoc`，WCN3990 | `ath10k_pci`，QCA6174。固件目录在 `ath10k/QCA6174/`，具体 hw 子目录在阶段 0 从内核日志核对 |
| 蓝牙 | `hci_uart` + `btqca` | `btusb`，USB `0cf3:e300` |
| 音频 | `sc7180-rt5682-max98357a-1mic` | `rk3399-gru-sound`（DA7219 + MAX98357A） |
| 触摸 / 笔 | Elan `04F3:2EC6` | Elan `ekth3500`，笔是 Wacom `2D1F:0036` |
| 视频 | Venus | Hantro |
| 高通用户空间 | qrtr、rmtfs、efs-loader、tqftpserv | 没有这些远程处理器，不编译、不启动 |
| 内置盘容量 | 64 GB 级，super 约 12 GB | eMMC 约 29 GiB。SD 上的 super 可以大；将来写回 eMMC 时按 32 GB 盘重新算，不能沿用 Trogdor 的 `BOARD_SUPER_PARTITION_SIZE` |

`shared/utils` 里的 qrtr、rmtfs、efs-loader、pd-mapper、tqftpserv，以及 `minigbm_msm`、Freedreno 的属性、`audio_policy_configuration_homestar.xml`、Elan/Wacom 那份 IDC，都不放进 Gru 的镜像。

可以改完再使用的有：`pack_kpart.sh` 的 FIT 结构（板名、压缩、DTB 通配符要换）、fstab 的标志语义、init 里 zram 和 cpuset 的写法、软件 KeyMint 的打包方式、传感器 subhal、`nl80211` 的 supplicant 配置。

## 软件栈

| 层 | 选择 |
| --- | --- |
| 引导 | 现有 depthcharge。板名 `gru`，压缩 lzma |
| 内核 | `linux-postmarketos-rockchip` 6.6.34-r6，加 Android 配置片段。不升 postmarketOS，不换 6.12 |
| 图形 | `rockchip-drm` + Panfrost + Mesa + `drm_hwcomposer` + minigbm。渲染 `skiagl` |
| 无线 | mac80211 / `ath10k_pci`，Android Wi-Fi HAL 走 nl80211 |
| 蓝牙 | 现有 `btusb`，配上 QCA6174 的 USB 固件 |
| 音频 | 现有 `rk3399-gru-sound`，AIDL 音频 HAL，策略文件按这块声卡写 |
| 电源 | `sbs-battery` 和 `cros_usbpd_charger`，接到 health HAL |
| 输入 | 触摸、笔、电源键和音量键走 evdev |
| 密钥 | 软件 KeyMint、软件 Gatekeeper |
| 分区 | SD 上的 Android 用动态 super。内核分区仍由 depthcharge 启动 |
| 策略 | bringup 期间 permissive |

Android 16 的官方通用内核是 6.12。阶段 2 的基线仍是 6.6.34。6.12 会让这块 Kingdisplay 面板疯狂闪屏。外置盘上的 `6.18.34-stb-cbg+` 充电正常，不能据此把基线换成 6.18。自己断电和电量突然变成 0 只出现在 postmarketOS 上，见 [阶段 0](phase-0.md)。设备 makefile 里关掉 VINTF 对内核版本的强制检查。缺的具体 eBPF 帮助函数到时候单独 backport，不因此更换内核系列。

`CONFIG_CFI_CLANG` 和 `CONFIG_SHADOW_CALL_STACK` 等这颗内核能进 Android 之后再单独试。

`third_party/pmaports-main` 是 pmaports 的 main 分支整树。[device-google-gru](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/tree/main/device/community/device-google-gru) 这一包有用，其余几千个包不进 Android 构建。这一包把启动几何再次定死：内核分区扇区 8192、长 65536、板名 `gru`、压缩 lzma。它依赖的固件包是 `linux-firmware-ath10k`、`linux-firmware-qca`、`linux-firmware-mrvl`、`linux-firmware-rockchip`。这台 Scarlet 用前两份；Marvell 是家族里其它板的无线；`rockchip/dptx.bin` 是外接 DP。

`modules-initfs` 列出亮屏前就要在的模块：`panel-kingdisplay-kd097d04`、`panel-innolux-p079zca`、`gpu-sched`、`elants-i2c`、`elan-i2c`、`atmel-mxt-ts`、`cros-ec-keyb`、`sbs-battery`、`spi-rockchip`。这台机器的面板是 Kingdisplay 那一项。这些如果在 6.6 里是模块，就放进 Android ramdisk。

睡眠唤醒靠的是 [c49c00d](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/commit/c49c00d09d1c9e266bd8c8e8ddae6e7255a5ee94)，不是换内核。这个提交把 `device-google-gru` 从 9 升到 10，只增加了 `systemd-gru-watchdog.conf`：

```ini
[Manager]
RuntimeWatchdogSec=30
```

这是 RK3399 上的 DesignWare 看门狗。当前系统是 8-r2，没有这份配置。6.6 上尝试休眠会整机崩溃，下次启动停在 bootloader。这份 30 秒的保活解决的是这次崩溃，不是 6.18 上那种十几毫秒就回来的休眠。Android 没有 systemd，把这个文件拷进镜像不会生效。第一份镜像里就要有一个从启动就打开 `/dev/watchdog` 的程序，把超时设成 30 秒，并在恢复之后立刻继续喂。用 6.12 换取这份保活会带上面板闪屏。6.18 的充电是好的，postmarketOS 上的断电和假空电不在那颗内核上复现。

同一份检出里的 `linux-postmarketos-rockchip` 已经是 7.2.9，补丁只涉及 PineNote。这不是阶段 2 的基线。6.6.34-r6 的配置向 v25.06 的包取。

`third_party/old` 是更早的一份 edge 检出，提交 `c49c00d`。里面的内核是 6.12.57，仍然不是这台机器上的 6.6.34-r6。它比 7.2 多的、和 Scarlet 直接相关的内容只有一块补丁：`0001-drm-panel-kingdisplay-kd097d04-Disable-EoTp.patch`。`dw-mipi-dsi` 默认打开 EoTp 之后，这块 Kingdisplay 面板花屏，补丁给面板加上 `MIPI_DSI_MODE_NO_EOT_PACKET`。补丁按 6.12 的 `devm_drm_panel_alloc` 写的，不能直接打到 6.6.34 上。6.6.34 还没有那个默认行为，所以阶段 2 不带这块补丁。以后如果必须离开 6.6，只移植这一行标志。这份 6.12 配置里 `CONFIG_CPUSETS_V1`、`CONFIG_EROFS_FS`、`CONFIG_USB_CONFIGFS_F_FS`、`CONFIG_SECURITYFS` 都是关的，不能当作 Android 配置的成品。

外置盘现在是 [velvet-os imagebuilder 的 chromebook_gru](https://github.com/velvet-os/imagebuilder/tree/main/systems/chromebook_gru) 打出来的 Debian 13（trixie）XFCE。`get-files.sh` 把内核钉在 `6.18.34-stb-cbg+`，包来自 [hexdump0815 的 stable 内核](https://github.com/hexdump0815/linux-mainline-and-mali-generic-stable-kernel/releases)，构建步骤在 [readme.cbg](https://github.com/hexdump0815/linux-mainline-and-mali-generic-stable-kernel/blob/master/readme.cbg)。这台机器上的 `uname` 是 2026-06-06 在 `aarch64-02` 上用 Debian gcc 14.2.0 编的，本地版本 `-stb-cbg`，末尾的 `+` 来自那份「把 dirty 标成加号」的补丁。根分区 btrfs 标签 `rootpart`。面板同样是 `kingdisplay,kd097d04`，DRM 模式 `1536x2048`，Mesa 25.0.7 Panfrost，glamor 已启用。XFCE 的显示配置是旋转 0、缩放 1、96 dpi。面板向 Xorg 报告的尺寸是 0 mm × 0 mm，所以 dpi 落在 Xorg 的默认值上，界面才会小。这是用户空间的缩放，Android 用 `ro.sf.lcd_density`。

竖屏流畅、旋转 90 度后卡顿，对得上 Xorg modesetting 的做法：面板时序保持竖屏，旋转靠一块影子帧缓冲，由 glamor 每帧把横屏画面转进竖屏扫描缓冲。RK3399 的 VOP 不能把主平面转 90 度扫描出去，`rockchip_rga` 虽然加载了，Xorg 也不用它。Android 的 SurfaceFlinger 不走这块影子帧缓冲。竖屏可以像现在这样直接扫描。横屏是 GPU 合成进同一块竖屏扫描缓冲，这是竖屏面板平板的正常路径，不会复现 XFCE 这种整屏软件旋转。它也不保证横屏和竖屏一样省。不能为了这条卡顿放弃 6.6。

这颗 6.18 已经打开 binderfs、functionfs、`SECURITYFS` 和 `DW_WATCHDOG`，Panfrost 编进内核。`CONFIG_SECURITY_SELINUX`、`CONFIG_EROFS_FS`、`CONFIG_FS_ENCRYPTION`、`CONFIG_ZRAM` 和 `CONFIG_CPUSETS_V1` 仍是关的。最后一项就是 Trogdor 亮屏前那次重启的开关。它说明有的 6.18 构建能点亮这块面板，充电口在采集时在线；还不是可以拿来编 Android 的树。2026-10-18 在这套系统上的两次 deep 休眠都没有停住，记录在 [阶段 0](phase-0.md)。耳机插孔在这台机器上是物理损坏。

## 阶段

每一段都有退出标准。没达到之前不开始下一段的实现。

### 0 基线

已结束。记录在 [阶段 0](phase-0.md)。eMMC 未写。覆写 SD 会清掉 velvet-os 的 Debian。

### 1 启动契约

做法、完成标准和分工在 [阶段 1](phase-1.md)。只写外置盘的内核分区。eMMC 不写。

### 2 Android 内核配置

做法、完成标准和分工在 [阶段 2](phase-2.md)。只改外置盘的内核分区，并往 Debian 根里加模块。eMMC 不写。休眠不测。

### 3 亮屏和 adb

做法、完成标准和分工在 [阶段 3](phase-3.md)。会改掉外置盘上 Debian 后面的分区。eMMC 不写。休眠不测。

### 4 平板日常

做法、完成标准和分工在 [阶段 4](phase-4.md)。按这个顺序补：Panfrost 加速、触摸和旋转、手写笔、背光、Wi-Fi、蓝牙、音频播放、电量和充电。启用 zram。镜像保持 vanilla。睡眠之前，`dw_wdt` 的保活必须已经在跑。

完成标准：在 4 GB 内存上完成一次「开机、联网、打开网页、安装应用、睡眠、唤醒」。唤醒后仍是同一次启动，而不是看门狗把机器打进 bootloader。电量不要出现 postmarketOS 上那种突然变成 0、插电后又回到 60% 到 70% 的读数。

#### 阶段 4.5：进入阶段 5 前的收尾与扩展项

原定阶段 4 的 9 项基础外设与 S3 睡眠唤醒已全部跑通，在进入阶段 5（打包可分发镜像）之前，按以下优先级完成收尾与外设扩展：

1. **系统 WebView 渲染黑屏与网页加载修复（P0，阶段 4 退出标准收尾）— 已完成**
   - **现象**：信息流联网正常、Geekbench 6 历史跑分列表可见（单核 317 / 多核 816），但点进 Geekbench 结果详情页（本地 WebView 渲染）黑屏、浏览器网页无法正常显示。
   - **根因**：主线 `6.6.34` 内核无 `/dev/ashmem`，系统启用了 `sys.use_memfd=true`。当 Chromium 将 Mojo IPC 环形缓冲区和光栅化共享内存 fd 传递给沙盒渲染进程 `com.android.webview:sandboxed_process0`（`isolated_app`）时，`ASharedMemory_getSize(fd)` 调用 `libcutils.so` 的 `is_memfd_fd(fd)`；原实现先执行 `readlink("/proc/self/fd/%d")` 检查路径前缀，而 `isolated_app` 进程因 `dumpable=0`（`/proc/self/fd` 属主为 `root:root 0500`）及 Chromium renderer seccomp-bpf 沙盒策略导致 `readlinkat` 返回 `EPERM`，进而回退尝试 `stat("/dev/ashmem...")` 失败（`ENOENT`），使所有共享内存大小返回 `0`，渲染进程陷入死循环（每秒刷出约 1.2 万行 `E ashmem` 日志）导致网页全黑。
   - **修复与验证**：修改 `system/core/libcutils/ashmem-dev.cpp` 中的 `is_memfd_fd(int fd)`，去除对 `/proc/self/fd` 的 `readlink` 依赖，直接通过 `fcntl(fd, F_GET_SEALS)` 判定 `memfd` 及 `F_SEAL_GROW | F_SEAL_SHRINK` 密封标志。实机验证 `E ashmem` 报错彻底清零，Geekbench 6 结果详情页与 LineageOS Jelly 浏览器网页均正常渲染显示，已固化入 `super.img`（`c4e8a01fea4dcfff8efe79e9e1efe0469d7901d790e0071a715790cab880f952`）。
2. **全功能 Type-C USB（MTP / PTP / 有线 adb + OTG Host 外设 + PD 充电共存）（P1）** — 详见 [全功能 Type-C USB 与 DP Alt Mode 调查与修复计划](usb.md)
   - **现状与根因**：`rk3399-gru.dtsi` 中 `usbdrd3_0` 已绑定 `extcon = <&usbc_extcon0>`，但子节点 `usbdrd_dwc3_0`（`fe800000.usb`）被写死为 `dr_mode = "host"`，内核未注册 UDC，且 `init` 中临时禁用了 USB Gadget；同时 `cros_usbpd-charger.c` 存在拔出 SDP 数据线漏发 `power_supply_changed()` 导致充电状态常驻的缺陷，USB 音频则缺少 `snd-usb-audio.ko` 等 6 个模块、策略引用与 VINTF `IModule/usb` 声明。
   - **目标**：按 [usb.md](usb.md) 顺序：（1）补齐 `snd-usb-audio.ko` + `usb_audio_policy_configuration.xml` + `IModule/usb` 打通 Type-C 转 3.5mm DAC 声卡；（2）修复 `cros_usbpd-charger` 与 `BatteryMonitor` 拔线后充电状态常驻；（3）将 `usbdrd_dwc3_0` 改为 `dr_mode = "otg"` 并启用 `init.mainline.usb.rc` 与 `vendor.usb-gadget-hal` 提供有线 `adb`、MTP、PTP 与 OTG 自动切换；（4）解决 DP Alt Mode 外接便携屏的 VBUS 供电与 VOP 图层缩放报错。
3. **V4L2 Stateless 硬件视频解码（`hantro_vpu` / `rockchip_vdec` -> Android `MediaCodec`）（P2，并为摄像头 V4L2 管线铺路）**
   - **剔除项**：剔除瑞芯微私有 `rkmpp` 路线（`rkmpp` 依赖下游 BSP 内核专有的 `/dev/mpp_service`，在主线内核上不可能工作；Linux 下 MPV 实际走的是主线 V4L2 Stateless Request API）。
   - **目标**：打包并加载 `hantro_vpu.ko`、`rockchip_vdec.ko`、`v4l2-mem2mem.ko`、`videobuf2-*` 模块（生成 `/dev/video*` 与 `/dev/media*`），配置/适配 Android Codec2 V4L2 HAL（`external/v4l2_codec2` / `system/cros-codecs` V4L2 Stateless），使系统 `MediaCodec` 注册硬件解码器（H.264 / HEVC / VP8 / VP9），让第三方客户端（如 PiliPlus 选 `auto / mediacodec`）与系统播放器直接走硬件解码，同时打通 V4L2 + `dma_heap` / `minigbm` 零拷贝缓冲区链路。
4. **USB-C DP Alt Mode 外接显示器（`cdn-dp` + `rockchip/dptx.bin`）（P3）**
   - **目标**：在第 2 步调通 Type-C `usbc_extcon0` 角色切换的基础上，将内置盘 `/lib/firmware/rockchip/dptx.bin` 放入 `/vendor/firmware/rockchip/dptx.bin`，打通 `phy-rockchip-typec` 与 `cdn-dp` 的 DP Alt Mode 握手与链路训练，验证 `drm_hwcomposer` 对外接显示器（`DP-1`）的热插拔投屏及 `pcmC0D3p`（`spdif-hifi-3`）DP 音频输出。
5. **在现有 `6.6.34` 内核上测试前后摄像头（`rkisp1` + `ov5695` / `ov2685` + `libcamera`）（P4，探索项）**
   - **剔除项**：**剔除「升级测试 postmarketOS 7.x 内核」**。经核对 `pmaports-main` 的 `7.2.9` 与当前 `6.6.34-phase2`，两者的摄像头配置完全一致（`CONFIG_PHY_ROCKCHIP_DPHY_RX0=y`、`CONFIG_VIDEO_ROCKCHIP_ISP1=m`、`CONFIG_VIDEO_OV5695=m`、`CONFIG_VIDEO_OV2685=m`，且 `rk3399-gru-scarlet.dtsi` 中 `wcam`、`ucam`、`isp0`、`mipi_dphy_rx0` 均已启用）；7.x 并无针对 Gru 摄像头的专属补丁，而更换 7.x 内核会引入 DSI EoTp 闪屏、cgroup 与 S3 深度休眠失效等严重回归。
   - **目标**：保持稳定的 `6.6.34-phase2` 内核不变，在第 3 步打通 V4L2 管线后，加载现有的 `rockchip-isp1.ko`、`ov5695.ko`、`ov2685.ko` 及 V4L2 依赖模块，结合树内的 `external/libcamera`（`rkisp1` pipeline，`TARGET_CAMERA_PROVIDER_HAL := libcamera`）探索前后摄像头预览与拍照。

### 5 可分发的 SD 镜像

本仓库提供打包脚本和安装说明：开发者模式、允许外置盘启动、写入 SD、校验和。FIT 里至少有已验证的 `scarlet-kd`。

完成标准：按文档从零写入一张卡可以启动。eMMC 上的 postmarketOS 仍在。

### 6 同族

`/boot` 里已经有 `scarlet-inx`、`scarlet-dumo`、`kevin`、`bob` 的 DTB。放进同一张 FIT 只表示固件能选中，不表示用户空间已经配好。面板、键盘、音频路由和传感器方向按板子改。没有实机的型号标成未验证。

完成标准：除这台 Scarlet 外，至少一台 Gru 用同一张卡进入桌面。

### 7 内置盘和后续版本

eMMC 安装单独做。29 GiB 的盘装不下 Trogdor 那份约 12 GiB 的 super，分区大小在这一段按实盘计算。写 eMMC 之前，SD 上的 Android 必须能重复启动。

Android 17 在阶段 4 或阶段 5 完成之后，把同一份 `device/google/gru` 换到新的 Lineage 源码树上，而不是现在另起一份移植。

SELinux enforcing、从源码构建内核、安装和升级说明，放在有可重复 SD 镜像之后。

## 明确后做

- 安装到 eMMC
- Android 17
- OTA
- GApps、Widevine
- kevin、bob，以及没有机器在手上的 Scarlet 面板变体

## 这个仓库

这里放路线、板级设备树、local manifest 和 SD 打包脚本。LineageOS 树在 `/run/media/alpha/YMTC/lineage-23.2`。那棵树里已有的 `device/google/trogdor` 是上次移植留下的，Gru 不继承它。

Soong 不跟随目录符号链接。设备树放到 Android 树里时，每个文件单独链回这个仓库，和上次 Trogdor 的做法相同。

当前进度：阶段 0～3 及阶段 4 原定 9 项（Panfrost、zram、触摸/旋转/手写笔、背光、Wi-Fi 与无线 `adb`、蓝牙、音频、电量与充电、S3 睡眠唤醒）已全部跑通；下一步按「阶段 4.5」顺序推进 WebView 黑屏修复、全功能 Type-C USB、V4L2 硬解、DP Alt Mode 外接屏与 6.6.34 下的摄像头测试。
