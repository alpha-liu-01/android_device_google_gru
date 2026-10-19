# 阶段 3：亮屏和 adb

用已经编好的 `6.6.34-phase2`，在外置盘上启动第一份 Android。源码树在 `/run/media/alpha/YMTC/lineage-23.2`。不换内核，不写 eMMC。阶段 2 的记录在 [阶段 2](phase-2.md)。

产品形态以 `third_party/android_device_google_trogdor-lineage-24` 为准。那是另一位开发者做完并且能用的 Trogdor 设备树。`third_party/failed_docs` 只用来避开已经发生过的启动故障。两边不一致时，跟做完的设备树。那份笔记里的静态 ext4 system、HIDL `drmfb-composer` 和高通固件，不进这份镜像。

## 完成标准

1. 启动菜单选外置盘后，面板上出现画面。
2. 用 USB 线接到工作站后，`adb` 能进入系统。
3. 再选内置盘，postmarketOS v25.06 进到图形会话。eMMC 的分区表和 `pmOS_kernel` 没有被写入。

触摸、旋转、背光、Wi-Fi、蓝牙、音频、电量和充电留到阶段 4。休眠不测。耳机插孔不测。

面板在用户空间点亮屏幕之前是黑的。若选外置盘后大约两分钟仍然没有画面，回到内置盘。启动日志写在外置盘一个单独的 ext4 分区上，标签 `bootlog`，文件是 `/gru-phase3.log`。这次会拆掉现在的 `bootpart`，所以不能再把日志写到那里。

## 这次做什么

在这个仓库里建立 `device/google/gru`，再逐个文件链进 Android 树。Soong 不跟随目录符号链接。不继承 Android 树里已有的 `device/google/trogdor`，那是上次没做完的移植。

做完的 Trogdor 树提供这些，Gru 照这个骨架改板级项：

| 项 | 做完的 Trogdor 树 | 这台 Scarlet |
| --- | --- | --- |
| 产品 | `lineage_trogdor`，平板、仅 Wi-Fi | `lineage_gru`。`lunch` 写成 `lineage_gru trunk_staging userdebug`。少写 `trunk_staging` 时，userdebug 会被当成 release |
| 分区 | 动态 super，system、vendor、system_ext、product 和 dlkm 是 erofs | 同样。`BOARD_SUPER_PARTITION_SIZE` 按这张 58 GiB 的 SD 计算，不用 Trogdor 的约 12 GiB，也不按 29 GiB 的 eMMC 算 |
| 数据 | userdata 是 f2fs，metadata 是 ext4，并且 `first_stage_mount` | 同样。userdata 在 first stage 就可写 |
| 图形 | AIDL `drm_hwcomposer`，minigbm 的 msm platform，Mesa 或 swangle | composer 仍是 AIDL `drm_hwcomposer`。minigbm 用 Rockchip / Panfrost 那个 platform。第一帧可以先用 SwiftShader。不使用 HIDL `drmfb-composer` |
| 显示 | `1200x1920`，密度 160 | `1536x2048`，密度 260 |
| 密钥 | 设备 manifest，软件 KeyMint 的片段从 APEX 并入 | 第一份镜像就带 device manifest。没有这份文件时，KeyMint 片段进不了清单 |
| 内核命令行 | `androidboot.selinux=permissive`，`deferred_probe_timeout=30`，没有 `binder.impl=rust` | 再加上 `security=selinux`。这颗内核的 `CONFIG_LSM` 是空的，不加这一项就挂不上 `selinuxfs` |
| 无线和音频 | nl80211，但 HAL 和策略文件是高通的 | 阶段 3 不把 Wi-Fi 和音频当作完成标准。策略文件以后按 `rk3399-gru-sound` 写 |

不编译、不启动 qrtr、rmtfs、efs-loader、pd-mapper、tqftpserv。不放 Freedreno 的属性、`minigbm_msm`、Adreno 固件、Trogdor 的音频策略和 IDC。

内核用阶段 2 的 `6.6.34-phase2` 和 `rk3399-gru-scarlet-kd.dtb`，板名 `gru`，压缩 lzma。构建时加 `--root none`。命令行是：

```text
console=tty0 loglevel=7 deferred_probe_timeout=30 security=selinux androidboot.selinux=permissive androidboot.hardware=gru androidboot.boot_devices=fe320000.mmc printk.devkmsg=on
```

不写 `binder.impl=rust`，不写 `root=` 或 `pmos_root_uuid`。`depthchargectl` 会加上 `kern_guid=%U`。

ramdisk 里要有：USB gadget 的 `libcomposite` 和 functionfs 模块，Kingdisplay 面板、Elan 触摸、EC 键盘和 `sbs-battery` 模块，以及 netd 还依赖的 nftables 模块。这些在挂分区和启动 netd 之前加载。erofs、ext4、f2fs 和 device-mapper 已经编进内核。6.6 没有 `CONFIG_CPUSETS_V1`，不把 6.12 的那个开关打进来；若 cpuset 挂载失败，记在日志里再处理。

从启动就打开 `/dev/watchdog`，超时 30 秒，并持续喂它。这是为了避免以后休眠时整机崩进 bootloader。这一段不测休眠。

内核分区仍是 32 MiB。FIT 装不下时停止，不加大 `KernelA`。

外置盘的分区在写入前先把表给你看。`KernelA` 和 `KernelB` 保持现在的 32 MiB。后面改成 super、metadata、userdata、misc，再加一个小的 ext4，标签 `bootlog`。`bootpart` 和 `rootpart` 会被删掉，Debian 13 进不来了。只写 `mmcblk0`。目标如果是 `mmcblk1` 或当前启动盘，不写。

## 你来做

1. 停在内置盘的 postmarketOS。上次地址是 `user@10.0.0.133`。地址变了就告诉我。
2. 确认可以擦掉外置盘上的 Debian。`bootpart`、`rootpart` 和里面的系统都会消失。`KernelB` 的位置留着，但选外置盘时启动的是新的 Android 内核槽。eMMC 不动。我改分区表之前会把新的分区表发给你，等你确认后再写。
3. 我挂载或写入时，如果 `doas` 或 `sudo` 要密码，在机器上输入。我看不到这个密码。
4. 我说镜像已经写好之后：重启，菜单选外置盘。看到画面就告诉我。大约两分钟仍然全黑，就改选内置盘，把地址告诉我。日志我来读。
5. 有画面之后，用 USB 线把平板接到这台工作站，让我检查 `adb`。
6. 再重启回内置盘，确认 v25.06 还在桌面，把地址告诉我。

外置盘起不来或回到选盘菜单时，重启改选内置盘。内置盘的内核分区这次不会写。不要休眠。

## 我来做

你停在内置盘、我能 SSH 进去之后：

1. 确认 `uname -r` 是 `6.6.34`，根分区是 `mmcblk1p3`，外置盘是 `mmcblk0` 且没有被挂成 `/`。对不上就停止。
2. 在这个仓库写 `device/google/gru`，按上面的表从做完的 Trogdor 树改。逐个文件链进 `/run/media/alpha/YMTC/lineage-23.2`。不继承那棵树里的 `device/google/trogdor`。
3. `lunch lineage_gru trunk_staging userdebug`，编出 super、userdata 和 ramdisk。内核用现成的 `6.6.34-phase2`。
4. 算出外置盘的新分区表，发给你。你确认之前不写。
5. 只写 `mmcblk0`。写入前后核对 eMMC `pmOS_kernel` 的校验和。现在的校验和是 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。
6. 你选过外置盘、再回到内置盘之后，读 `bootlog` 上的 `/gru-phase3.log`，并核对根仍是 `mmcblk1p3`、eMMC 校验和未变。

## 实现顺序

| 步 | 谁 | 做什么 | 通过条件 |
| --- | --- | --- | --- |
| 1 | 你 | 停在内置盘，并确认可以擦掉 SD 上的 Debian | SSH 上是 6.6.34，根在 `mmcblk1p3` |
| 2 | 我 | 建立 `device/google/gru` 并编出镜像 | 镜像还没写盘 |
| 3 | 我 | 把新的分区表发给你 | 你确认之前，外置盘的分区表不变 |
| 4 | 你 | 确认这张表 | 明确说可以写 |
| 5 | 我 | 只改外置盘并写入 | FIT 不超过 32 MiB；eMMC 内核分区校验和不变 |
| 6 | 你 | 菜单选外置盘 | 面板上有画面 |
| 7 | 你 | USB 接到工作站 | `adb` 能进入系统 |
| 8 | 你 | 菜单选回内置盘 | v25.06 进桌面 |
| 9 | 我 | 读 `/gru-phase3.log`，再核对内置盘 | 根在 `mmcblk1p3`，eMMC 内核分区校验和仍不变 |

第 6 步若一直黑屏，先回到内置盘，用第 9 步的日志判断停在哪里。第 6 步到第 9 步都对上之后，阶段 3 结束。

## 实现笔记

2026-10-18。人在内置盘。`uname -r` 是 `6.6.34`，根是 `/dev/mmcblk1p3`，外置盘 `mmcblk0` 共 122167296 个 512 字节扇区，没有挂到 `/`。postmarketOS v25.06。

`device/google/gru` 写在这个仓库里，每个文件单独链到 `/run/media/alpha/YMTC/lineage-23.2/device/google/gru`。没有继承那棵树里的 `device/google/trogdor`。

`lunch lineage_gru-trunk_staging-userdebug` 已通过。composer 是 `drm_hwcomposer`，图形是 SwiftShader，allocator 是 `minigbm-upstream`，`TARGET_NO_KERNEL` 为 true。这棵 23.2 的 minigbm 没有名为 rockchip 的 platform。`generic` 走 dumb rockchip 后端。`DRV_ROCKCHIP` 调用的是下游 GEM ioctl，6.6 主线内核没有这个接口，所以不用。也不用 msm。`external/drm_hwcomposer-upstream` 没有 `Android.bp`，所以用 `external/drm_hwcomposer` 里的 AIDL HWC3 APEX。

命令行按本文上面的那一行，没有 `binder.impl=rust`。做完的 Trogdor 树还有 `androidboot.boot_part_uuid=%U`。这颗 6.6 的分区事件只带 `PARTN` 和 `PARTNAME`，没有 `PARTUUID`，init 对不上这个值就会空等后重启，所以这份 FIT 不加它。`androidboot.boot_devices=fe320000.mmc` 是外置盘控制器。没有它时，init 不把这块盘当成启动盘，也就不建立 `/dev/block/by-name/super`，逻辑分区挂不上。eMMC 是 `fe330000.mmc`，不写进这一项。

ramdisk 里放了 89 个未压缩模块：面板、DSI phy、functionfs、Elan、EC 键盘、`sbs-battery`、`loop`、`xfrm_user`，以及 nftables 和 xt 模块。`CONFIG_BLK_DEV_LOOP=m` 且 `MIN_COUNT=0`，不加载 `loop.ko` 就没有 `/dev/loop-control`，APEX 挂不上。`CONFIG_XFRM_USER=m`，不加载 `xfrm_user.ko` 时 netd 初始化 `XfrmController` 会以状态 3 退出，并在 `onrestart` 里重启 zygote。`gru-keep` 在执行 Android init 之前加载 `watchdog.ko` 和 `dw_wdt.ko`，把看门狗超时设成 30 秒。诊断启动证明内核能进用户空间，但 sysfs 刚挂上时只有 eMMC（`mmcblk1` 的 `pmOS_kernel`、`pmOS_boot`、`pmOS_root`）。外置盘的 `sdmmc` 控制器稍后才注册，`misc` 和 `bootlog` 是重试之后才出现的。Android 若在这之前启动，找不到 `super`，就会重启回选盘菜单。现在先等到 `PARTNAME=super` 出现，把当时的分区表和 `kmsg` 写入 `/gru-phase3.log`，再执行 `/init.android`。proc 和 sysfs 先挂在 `/gru-proc`、`/gru-sys`，不占用 Android 自己要挂的 `/proc` 和 `/sys`。执行之前把这三个挂载拆掉：`/system` 是只读 erofs，里面没有 `gru-proc`、`gru-sys`、`bootlog`，`SwitchRoot` 挪不过去就会重启。日志文件描述符在拆掉之后仍然可写。

分区表在 `device/google/gru/partition-table.txt`。super 是 8 GiB。`super.img` 展开后正好是这个大小，文件本身 1.2 GiB。`userdata.img` 是 4 GiB 的 f2fs 稀疏镜像；真正的 userdata 分区大约 50 GiB，第一次写入时已经格式化成 f2fs。后面的写入只覆盖 `KernelA` 和 super，不再格式化 userdata。FIT 小于 32 MiB 的内核槽。打包出的命令行是 `kern_guid=%U` 加上本文规定的那一行，没有 `root=`。分区表已经写在外置盘上，不再改。

## 事件

| 日期 | 事件 |
| --- | --- |
| 2026-10-18 | 停在内置盘，确认可以擦掉外置盘上的 Debian。内核 6.6.34，根在 `mmcblk1p3`。 |
| 2026-10-18 | `device/google/gru` 已链进源码树。`lunch` 通过。 |
| 2026-10-18 | super、userdata、ramdisk 编完。FIT 13950976 字节。分区表已给出，等待确认后才写外置盘。 |
| 2026-10-18 | 第一次写入在改完外置盘分区表后停在 `ABORT_GPT`。新分区没有 Attr 行，检查把第 4 到第 7 分区漏掉了。格式化和内核都还没写。eMMC 没写。检查已改，可以重跑同一条命令。 |
| 2026-10-18 | 重跑后 `WRITE_OK /dev/mmcblk0p1 13950976`。内核校验和两边都是 `221c53d8377e10a8515e78515f3a1586ea78a7deea8c546d65122197514baf94`。eMMC 校验和和分区表未变。 |
| 2026-10-18 | 选外置盘后大约 5 秒回到选盘菜单，画面全黑。`readlog.sh` 打印 `LOG_MISSING`，`bootlog` 里只有 `lost+found`。`KernelA` 仍是 priority=10、tries=2、successful=1。eMMC 校验和未变。失败的 Trogdor 笔记里，同样立刻返回的原因是 `selinuxfs` EINVAL、system 没有 `first_stage_mount`、ext4 是模块。这三件在当前 FIT 里已经分别由 `security=selinux`、fstab 和编进内核的文件系统处理。6.6 没有 `PARTUUID` 事件，不能照搬做完的树里的 `androidboot.boot_part_uuid=%U`。 |
| 2026-10-18 | `write-kernel.sh` 打印 `WRITE_OK /dev/mmcblk0p1 13950976`。只覆盖了 `KernelA`。镜像和写入字节的校验和都是 `30fc19727014b66d06ecc2bf14c85289c44e0d202ee921fe33231edb73bd2b67`。eMMC 校验和未变。 |
| 2026-10-18 | 再次选外置盘，仍是大约 5 秒回到选盘菜单。`readlog.sh` 仍是 `LOG_MISSING`。eMMC 校验和未变。这份 FIT 里的 `gru-keep` 会在执行 Android init 之前写日志，文件仍不存在，所以 init 要么没跑到，要么在挂上 `bootlog` 之前就被重启打断。 |
| 2026-10-18 | 诊断镜像不启动 Android。黑屏停住，人工关机后回到内置盘。`/gru-phase3.log` 678 字节。`6.6.34-phase2` 已进用户空间，看门狗模块和设备都打开成功。命令行里的 `kern_guid` 是外置盘 KernelA `73b52be6-095d-9843-a584-d00cc11dcb63`。第一次列出的块设备只有 eMMC。`misc=ok`，说明外置盘是稍后才出现的。日志在 `misc=ok` 处结束，没有 `bootlog=` 这一行，因为那一行是写完文件之后才加进缓冲区的。 |
| 2026-10-18 | 等到 `super` 后再启动 Android。大约 5 到 6 秒回到选盘菜单。日志是追加的，里面有两次启动。内核时间约 0.9 秒跑到 `/init`，约 1.3 秒出现 `mmc0`，约 3.7 秒和 4.5 秒各有一次 `init first stage started`。先写进去的那次已经走到模块加载：`modules.dep` 里没有依赖的行带了尾部空格，init 把空字段当成 `/lib/modules/6.6.34-phase2/`，拒绝加载 `nf_tables`。它随后仍去读 fstab，所以这次重启不是停在模块错误上。设备树里没有 fstab 是预期的。真正的退出原因在这之后，后一次启动没来得及把那一行刷进日志。 |
| 2026-10-18 | 修好 `modules.dep` 之后再启动。磁盘上的 `/gru-phase3.log` 停在 `Loading module .../nft_reject_inet.ko`（内核时间约 4.87 秒）。屏幕比文件多出后半秒：87 个模块都加载完（658 ms），面板点亮，`Console: switching to colour frame buffer device 192x128`。`rockchip/dptx.bin` 报 error -2，只是缺固件。随后 `[libfstab] ReadFstabFromDt(): failed to read fstab from dt`，再下一行是 first stage 挂载失败并 `InitFatal`。设备树里没有 fstab 是预期的。`fstab.gru` 在 ramdisk 里，super 里的六个逻辑分区都是合法 erofs。失败是因为命令行没有 `androidboot.boot_devices`，init 不建立 `/dev/block/by-name/super`。 |
| 2026-10-18 | 新 FIT 已放在 `/home/user/phase3/kernel.kpart`，14024704 字节，校验和 `77162ed5e7244b74d6c042c7a334adcd038d272ca510d3094830937ddad3fdae`。命令行增加 `androidboot.boot_devices=fe320000.mmc`。`depthchargectl check` 识别为 scarlet。还没写入 `KernelA`。上一份在 `kernel.kpart.prev`。 |
| 2026-10-18 | 写入并启动了带 `boot_devices` 的 FIT。87 个模块加载完，面板点亮。metadata 挂上了。六个逻辑分区建成，`/system` 的 erofs 挂载成功。随后 `Switching root to '/system'`，`Unable to move mount at '/gru-proc' to '/system/gru-proc': No such file or directory`，`InitFatalReboot: signal 6`。`/system` 是只读 erofs，没有 `gru-proc`。`dptx.bin` error -2、metadata 上没有 `e2fsck`、复制 `/avb` 失败，都不是这次重启的原因。磁盘日志仍停在 `bridge.ko`，这几行只在屏幕上。 |
| 2026-10-18 | 新 FIT 在 `/home/user/phase3/kernel.kpart`，14024704 字节，校验和 `b39770a12eb039fd09263618872a1296388f962689cc87bdb6979025cefcad92`。执行 Android init 之前拆掉 `/bootlog`、`/gru-proc`、`/gru-sys`。命令行未改。`depthchargectl check` 识别为 scarlet。还没写入 `KernelA`。上一份在 `kernel.kpart.prev`。 |
| 2026-10-18 | 拆掉额外挂载之后启动，过了切根。约 9.7 秒 apexd 要预分配 58 个 loop，随后一直 `Failed to open loop-control: No such file or directory`。runtime 等 APEX 没挂上，`linker64` 不在，`wificond`、`keystore2`、`audioserver`、`zygote` 都是退出状态 127。约 39 秒 init 自己关机，`Reboot ending, jumping to kernel`。`cgroup.kill` 和 `/dev/cpuset` 不存在，这次先记下，不改内核。`dptx.bin` error -2 仍不是重启原因。 |
| 2026-10-18 | 新 FIT 在 `/home/user/phase3/kernel.kpart`，14082048 字节，校验和 `e6df63dc3e47a97dbca18c9a3de14a6d4fd670d446d8cdad65ba4e1400ff5c3d`。ramdisk 增加 `loop.ko`，共 88 个模块。命令行未改。`depthchargectl check` 识别为 scarlet。还没写入 `KernelA`。上一份在 `kernel.kpart.prev`。 |
| 2026-10-18 | 带 `loop.ko` 的 FIT 已写入并启动。第一次选外置盘解压 APEX 用了几分钟后回到选盘菜单。第二次不再回到选盘菜单，停在服务循环。`apexd-bootstrap` 状态 0（1.671 秒），`bpfloader` 状态 0（2.177 秒）。约 98.8 秒 `netd`（pid 2893）状态 3，`onrestart` 杀掉 zygote，并因没有 `zygote_secondary` 失败。随后每约 5 秒重复。`vendor.usb-hal-1-3` 状态 1。`audioserver.rc` 要启动的 `vendor.audio-hal`、`vendor.audio-hal-4-0-msd`、`audio_proxy_service` 都不存在。wificond 找不到 `nlinterceptor`，查找后继续。`flags_health_check UPDATABLE_CRASHING` 反复出现。surfaceflinger（pid 2941）在约 104 秒拉起了 bootanim。`cgroup.kill` 不存在，先记下，不改内核。约 69 秒 `dptx.bin` 加载超时，不是这次循环的原因。 |
| 2026-10-19 | netd 状态 3 是 `XfrmController::Init` 失败。`CONFIG_XFRM_USER=m`，`xfrm_user.ko` 没有依赖。USB HAL 状态 1 是 `registerAsService` 失败：设备清单里没有 `android.hidl.manager`，`hwservicemanager` 会把自己关掉。新 FIT 14155776 字节，校验和 `d32fbae5eb95d782ab4ec52301eb723d8b94c9f80c7cf8a753aea3079c8693af`，ramdisk 89 个模块。新 `super.img` 校验和 `a3eada7b95632a5cef0dcdde8224be2a3ab6907dd2fe2471d72a39c8b4b91877`，展开后仍是 8589934592。清单加入 `android.hidl.manager` 1.2 和 `android.hidl.token` 1.0。`depthchargectl check` 识别为 scarlet。还没写入外置盘。 |
| 2026-10-19 | `write-loopfix.sh` 打印 `WRITE_OK /dev/mmcblk0p1 14155776`。内核校验和两边都是 `d32fbae5eb95d782ab4ec52301eb723d8b94c9f80c7cf8a753aea3079c8693af`。super 也写入了。eMMC 校验和未变。 |
| 2026-10-19 | 这次不再回到选盘菜单，循环换了内容。`netd` 没有再以状态 3 退出，并注册了 `INetd`。`apexd-bootstrap` 和 `bpfloader` 仍是状态 0。surfaceflinger 拉起了 bootanim。`vendor.usb-hal-1-3` 在约 217 秒内以状态 1 退出 25 次，每 4 次触发 `flags_health_check UPDATABLE_CRASHING`。`start hwservicemanager` 失败，服务不存在；`HidlServiceManagement` 打印 HIDL 不受支持。原因是 `system_ext` 里没有 `hwservicemanager` 这个程序，`/system/bin/hwservicemanager` 只是断掉的符号链接。zygote 在约 136、163、190、214 秒收到 SIGKILL。init 是在这之后才清理进程组。zygote 在 system_server 退出时会对自己发 SIGKILL，这句话只进 logd。随后 zygote 的 onrestart 杀掉 netd、audioserver，并写 `/sys/power/state` 得到 EINVAL。`audioserver` 找不到 `activity`，是 system_server 还没把 ActivityManager 注册出来。`vendor.audio-hal`、`vendor.audio-hal-4-0-msd`、`audio_proxy_service` 仍不存在，AIDL 音频 HAL 在跑。`nlinterceptor` 找不到后继续。`cgroup.kill` 仍不存在。`logd` 的 `HexToBytes: Invalid size: 17` 是审计路径不是偶数位十六进制，同一处还有 `Invalid characters`、size 55 和 133，不是新的故障。`misctrl` 和 `chattr +F /data/media` 状态 1，`recovery-refresh` 状态 254，`prng_seeder` 因没有 `/dev/hw_random` 挂起。`dwmmc_rockchip fe320000.mmc` 报了 10 次 `Unexpected interrupt latency`。这些不驱动循环。 |
| 2026-10-19 | `system_ext` 放入 `hwservicemanager` 和 `zz-gru-kmsg.rc`。新 `super.img` 校验和 `5bc87b7735d372331a280b0687cdeda7a92f2eb70925a4fb8fec41dbdcc18df4`，展开后仍是 8589934592。内核分区不动。还没写入外置盘。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。super 校验和 `5bc87b7735d372331a280b0687cdeda7a92f2eb70925a4fb8fec41dbdcc18df4`。eMMC 校验和未变。 |
| 2026-10-19 | 这次仍停在服务循环，没有回到选盘菜单。`hwservicemanager`（pid 2257）起来了，`vendor.usb-hal-1-3`（pid 2905）启动后没有再以状态 1 退出。屏幕上把 `gru_kmsg` 的 pid 看成 USB HAL 退出，和磁盘日志对不上。`netd` 仍注册了 `INetd`，只在 zygote 的 onrestart 里被杀掉。约 99 秒 bootanim 起来。zygote 在约 143.5、170.8、197.4、221.9、246.2、270.4 秒收到 SIGKILL，原因仍是 system_server 先退出。`class_start main` 整段日志里没有出现：`/vendor/etc/init/hw/init.gru.rc` 和 `/init.gru.rc` 都不存在，second stage 没有 `mount_all`，`nonencrypted` 没人触发，`installd` 所在的 class main 没启动。`audioserver` 每秒找 `activity` 是 ActivityManager 没注册出来。`gru_kmsg` 用 `logcat -f /dev/kmsg`，约 128.9 秒 `SocketClient: write error (Broken pipe)` 后以状态 1 退出 29 次，apexd 想回滚但没有 session。一行 AndroidRuntime 都没进 kmsg。`cdn-dp` 对 `rockchip/dptx.bin` 报 error -2 六次，约 68.6 秒超时；这颗内核的固件路径默认是 `/lib/firmware`，64 秒内会加倍重试。`logd` 的 `HexToBytes`（size 17、11）仍是审计路径。`dwmmc_rockchip fe320000.mmc` 有 `Unexpected interrupt latency`，还有一次 `CTO timeout when already completed`。`cgroup.kill` 仍不存在。这些不驱动这次循环。 |
| 2026-10-19 | 新 `super.img` 校验和 `44933c11b22676b62b9615597f87022f4c3aaccbad6e256ab0405d5d86c751c9`，文件 1273909680 字节，展开后仍是 8589934592。vendor 放入 `init.gru.rc`（`mount_all`，并在 early-init 把 `firmware_class.path` 写成 `/vendor/firmware`）和 postmarketOS 上的 `rockchip/dptx.bin`（98320 字节，校验和 `203c5f061fb5075e4ca5398f8becc74e7cc450b494af857da5400788a7eae20b`）。`zz-gru-kmsg.rc` 拿掉了。内核分区不动。还没写入外置盘。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。super 校验和 `44933c11b22676b62b9615597f87022f4c3aaccbad6e256ab0405d5d86c751c9`。eMMC 校验和未变。 |
| 2026-10-19 | 这次循环更密，没有回到选盘菜单。`mount_all` 跑了，`class_start main` 用了 944 ms，`installd`（pid 2999）在约 100.4 秒启动。bootanim（pid 3037）约 101 秒。`dptx.bin` 只在 4.2、5.3、7.3 秒报 error -2，early-init 在 10.4 秒改了固件路径之后没有再超时。zygote 仍在约 142.1、170.2、197.1、221.6、245.8 秒收到 SIGKILL，第一次活了约 46 秒，和上一轮没有 installd 时一样，所以不是在等 installd。kmsg 里没有 `system_server`、`AndroidRuntime`。画面变密是因为 `nonencrypted` 把 `class late_start` 拉起来了，`usbd`（pid 3040）从约 101.5 秒起一直懒启动 `android.hardware.usb.gadget.IUsbGadget/default`，和 `audioserver` 找 `activity` 交错。`/vendor/etc/init/hw/init.mainline.rc` 没有被解析，`sys.usb.configfs` 停在 0，gadget HAL 不会启动。`vendor.audio-hal` 和 `vendor.audio-hal-4-0-msd` 仍不存在。`nlinterceptor`、`cgroup.kill`、`HexToBytes` size 17、`dwmmc` 中断延迟、`write /sys/power/state` EINVAL 仍在，不驱动这次循环。 |
| 2026-10-19 | 新 `super.img` 校验和 `08d61157300cc721ec2397d324bb6acccdf0acfa4c92d716fab3e2d0ddd9f558`，文件 1273909680 字节。`init.gru.rc` 导入 `init.mainline.rc`，在 early-boot 把 `sys.usb.configfs` 设成 2，并加 `gru_logcat` 把 Zygote / AndroidRuntime / SystemServer 写到 `/data/gru-logcat.txt`。内核分区不动。还没写入外置盘。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。super 校验和 `08d61157300cc721ec2397d324bb6acccdf0acfa4c92d716fab3e2d0ddd9f558`。eMMC 校验和未变。 |
| 2026-10-19 | 这次循环换了位置，没有回到选盘菜单。`init.mainline.rc` 被解析，`vendor.usb-gadget-hal` 从约 33.7 秒起每约 5 秒 SIGABRT 一次。构造函数在 `sys.usb.controller` 为空或 configfs 还没建好时会 `abort()`。`usbdrd_dwc3_0` 在设备树里是 `dr_mode=host`，没有 UDC。四次之后 `flags_health_check UPDATABLE_CRASHING` 一直跑，日志里这种 exec 到了 73。`bcdVersion must be 0x0100` 来自 `f_fs.c`，functionfs 的 OS 描述符写成了 `0x0001`，内核接受后每次枚举打两行，共 444 行。`usbd` 仍找不到 `IUsbGadget`。zygote 仍在约 75、104、133、158、183、209、234、259、285 秒收到 SIGKILL，第一次从 29.2 秒活到 75.4 秒，仍是约 46 秒。`gru_logcat`（pid 2733）一直在跑，异常写在 `/data/gru-logcat.txt`，这次读不到那块盘。`dptx.bin` 仍只有启动前三次 error -2。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `0299388ed84232a9a682d28cbd04b9d552e75375a9586d74c7a1f59a328fc224`，文件 1273909680 字节。`vendor.usb.configfs` 设成 0，gadget HAL 不再启动。`usbd` 一起来就被停掉。`gru_logcat` 改成脚本，同一份过滤日志写到 `/data/gru-logcat.txt`，并逐行以 `GRU_LOG` 打进 kmsg。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。super 校验和 `0299388ed84232a9a682d28cbd04b9d552e75375a9586d74c7a1f59a328fc224`。eMMC 校验和未变。 |
| 2026-10-19 | 这次循环换到 system_server 自己退出，没有回到选盘菜单。gadget HAL 没有再 SIGABRT，`usbd` 约 102.7 秒被停掉。`class_start main` 用了 938 ms。zygote 约 96.5 秒启动，预加载 18793 个类用了 17045 ms。system_server（pid 3271）约 149.3 秒抛出 `java.lang.RuntimeException: Failed to create ashmem: No such file or directory`，栈在 `ApplicationSharedMemory.nativeCreate` 和 `SystemServer.run`。这颗内核没有 ashmem 设备，`libcutils` 在 `sys.use_memfd` 未设置时去打开 `/dev/ashmem` 加 boot id。zygote 随后在约 149.3、177.5、203.6 秒收到 SIGKILL，后两次是同一条异常。画面上的 `Class not found for preloading` 是预加载警告，预加载已经完成。`bcdVersion` 从 adbd 约 99.1 秒启动后大约每秒两行，共 192 行，是没有 UDC 时 functionfs 的警告，不驱动这次退出。`activity` 仍找不到，因为 system_server 没走到注册 ActivityManager。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `1e5a7c0aa3759b987dca0a42ecb254aa4e2551679d45ad18e44f2486c5cd0b8d`，文件 1273909680 字节。early-init 设置 `sys.use_memfd true`。`libcutils` 在 memfd 密封可用、但 `ASHMEM_GET_SIZE` ioctl 失败时仍走 memfd。system、vendor、product 三份 `libcutils.so` 都换了。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `1e5a7c0aa3759b987dca0a42ecb254aa4e2551679d45ad18e44f2486c5cd0b8d`。eMMC 校验和未变。 |
| 2026-10-19 | 这次 ashmem 不再失败，没有回到选盘菜单。审计里有 `memfd:test_android_memfd`。system_server、bootanim、launcher3、systemui、webview_zygote 都起来了。循环换成 `media.swcodec` SIGSEGV：空指针在 `C2AllocatorIon::setUsageMapper`（`/apex/com.android.media.swcodec/lib64/libcodec2_vndk.so`，BuildId `cd77cb1ae98335089114507675ab28c4`），调用链是 `UseComponentStoreForIonAllocator`、`fetchIonAllocator`。这颗内核没有 ION，`ion_open` 失败后 `mTraits` 仍是空。swcodec 退出 4 次后跑 `flags_health_check UPDATABLE_CRASHING`。system_server 线程 `NDK MediaCodec_` 随后 abort：`Codec2 AIDL service "software"does not have IConfigurable.` zygote 因此 SIGKILL。日志里这次 swcodec SIGSEGV 11 次，这条 abort 5 次，zygote SIGKILL 5 次。Launcher 和 SystemUI 的 AndroidRuntime 是 `DeadSystemException`。`bcdVersion` 仍来自 adbd，不驱动这次退出。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `b77e696ad6cf83cb58994e84289e3c20ee14fc0403a5a6e97eec302cbaa7b5b9`，文件 1273909680 字节。ION 分配器在 `ion_open` 失败时不再调用 `setUsageMapper`，改走 dma-buf 分配器；`mTraits` 为空时 `setUsageMapper` 直接返回。`libcodec2_client` 在软件 Codec2 没有 IConfigurable 时写日志并返回空，不再 abort system_server。apex 里的 `libcodec2_vndk.so` BuildId 换成 `e14d496a691b1d640e2cd87f59aa46c5`。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `b77e696ad6cf83cb58994e84289e3c20ee14fc0403a5a6e97eec302cbaa7b5b9`。eMMC 校验和未变。 |
| 2026-10-19 | 这次 `media.swcodec` 没有再 SIGSEGV，审计里有 `memfd:MessageQueue`。system_server、bootanim、launcher3 都起来了。循环换成 batterystats：`synchronizeKernelRCU failed: Unknown error -97`。`BpfNetMaps.swapActiveStatsMap` 用 `AF_KEY` 套接字的 `close()` 等 `synchronize_rcu()`。`CONFIG_NET_KEY=m`，`af_key` 没加载，`socket()` 返回 EAFNOSUPPORT（97），这条未捕获异常把 system_server 杀掉。zygote 因此退出 6 次，大约每分钟一次（06:24:39 到 06:29:58）。SystemUI 在重启间隙有一次 `Looper.mQueue` 空指针，是 system_server 已死之后的连带崩溃。`elants_i2c` 的 unknown packet、`bcdVersion` 仍在，不驱动这次退出。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `86ae7e8d00d81f5b87a2b15675ef5a106240171468b8c0ec812769c7b66b5848`，文件 1273942448 字节。early-init `insmod /vendor/lib/af_key.ko`。模块无依赖，vermagic 是 `6.6.34-phase2`。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `86ae7e8d00d81f5b87a2b15675ef5a106240171468b8c0ec812769c7b66b5848`。eMMC 校验和未变。 |
| 2026-10-19 | 这次不再循环。`af_key.ko` 由 init 加载。bootanim 约 231 秒以状态 0 退出，launcher3 已创建，约 232 秒 `sys.boot_completed=1`。大约 77 秒后内核打印 `PM: suspend entry (deep)`，文件系统同步之后停在 `Freezing user space processes`。日志到这里结束，机器回到 bootloader，音量键不能用，和 postmarketOS 上 6.6 睡眠直接掉回 bootloader 是同一条路。蓝牙 HAL 在这之前反复 SIGABRT（`initializationComplete` 不是 SUCCESS，以及 `FD_SET: file descriptor -1`），音频 effect HAL 报 `create EventFlagGroup failed`。这两处没有把 system_server 杀掉，也不是这次关机的原因。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `8448e9a4420a9f414a4c8bedcf513fbb38c5a3975f816710554f1fa346ba5fc1`，文件 1273942448 字节。post-fs 把 `/sys/power/state` 设成 `000`。`system_suspend` 以 uid system 打开失败后继续提供 wake lock，但不会再写 `mem`。`sys.boot_completed=1` 时把 `screen_off_timeout` 设成 86400000 毫秒。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `8448e9a4420a9f414a4c8bedcf513fbb38c5a3975f816710554f1fa346ba5fc1`。eMMC 校验和未变。 |
| 2026-10-19 | 这次 system_server 没有退出，也没有进入睡眠。systemui 和 launcher3 都创建了，bootanim 约 221 秒以状态 0 退出，约 201 秒 `sys.boot_completed=1`，亮屏超时那条命令用了 484 ms 并且成功。`chmod 000` 成功时 init 不记日志。画面上的循环是 `adbd`：没有 UDC，它仍打开 functionfs，内核从约 98 秒到日志结束打了 722 次 `bcdVersion`，大约每秒一次，还有 `read descriptors`。`vendor.bluetooth-default` 启动了 7 次，abort 信息是 `initializationComplete` 不是 SUCCESS，以及 `FD_SET: file descriptor -1`。音频 effect HAL 有一次 `create EventFlagGroup failed`，audioserver 以状态 1 退出过。这三处都没有把 zygote 杀掉。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `951036474921cd99f28738cf59f9958b707dc930fd4ac1e9ad0d69b6f381ca28`，文件 1273942448 字节。`adbd` 和 `vendor.bluetooth-default` 一起来就被停掉。`com.android.bluetooth` 在启动完成后 disable。控制台 loglevel 降到 3，kmsg 仍全量进日志。没有 UDC，adb 这次不会起来。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `951036474921cd99f28738cf59f9958b707dc930fd4ac1e9ad0d69b6f381ca28`。eMMC 校验和未变。 |
| 2026-10-19 | 这次没有回到 bootloader，也没有进入睡眠。zygote 没有退出。launcher3 约 188 秒创建，约 197 秒 `sys.boot_completed=1`，bootanim 约 211 秒以状态 0 退出。屏幕停在 197 秒是因为这时把控制台 loglevel 降到 3，后面的 kmsg 仍写到约 694 秒，healthd 每分钟报一次电量。`adbd` 被停掉之前打了几次 `bcdVersion`，之后没有再打。`com.android.bluetooth` 在 disable 之前崩了 4 次：HAL 已被停掉，应用卡在 `HciBackend::CreateAidl` 的 `waitForService`，然后被杀掉；`pm disable` 用了 338 ms 并且成功。SystemUI 约 166 秒 ANR，原因是启动没在时限内完成，进程没有退出，bootanim 当时占着 CPU。音频 effect HAL 约 201 秒 SIGABRT，`create EventFlagGroup failed`，栈在 `libbundleaidl.so` 的 `EffectContext`；它的 `onrestart` 把 audioserver 杀掉又拉起来。音频 apex 里的 `libcutils.so` 仍是没打 memfd 补丁的那份（BuildId `cab2e8af15a0c70490656050e5c0d65a`），FMQ 分配失败后 `LOG_ALWAYS_FATAL`。`sbs-9-000b` 的 `current_avg` 和 `technology` 返回 -5，F2FS 报不能开 fs-verity。这两处不杀进程，也不改分区。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `4b6e49631af593de5a50ff10c10b47c5a4b03e7fc606efc5dd14c47ccbc84c9f`，文件 1273942448 字节。音频 apex 的 `libcutils.so` BuildId 换成 `70de067737fddceddd34c8c7187b9985`，`ASHMEM_GET_SIZE` 失败时仍走 memfd。early-init 设置 `debug.sf.nobootanimation 1`。`sys.boot_completed=1` 先写一行 `<2>gru: userspace is up, console log is now quiet`，再把控制台 loglevel 降到 3。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `4b6e49631af593de5a50ff10c10b47c5a4b03e7fc606efc5dd14c47ccbc84c9f`。eMMC 校验和未变。 |
| 2026-10-19 | 这次回到服务循环，没有进入睡眠，也没有 `sys.boot_completed`。system_server 在 `startOtherServices` 里构造 `BluetoothService` 失败：`No service can handle intent { act=android.bluetooth.IAdapter pkg=com.android.bluetooth }`。上一轮 `pm disable com.android.bluetooth` 写进了 userdata，包已经是禁用的。zygote 因此大约每 30 秒退出一次，从约 176 秒到 359 秒共 7 次。音频 effect HAL 没有再 SIGABRT，审计里有 `memfd:MessageQueue`。`flags_health_check UPDATABLE_CRASHING` 是这次退出的连带。`activity` 找不到也是 system_server 还没注册。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `0b61a1819b1f9d7c45edadce55bcf81aec6b7902b4d24d5527a70237f26382cf`，文件 1273942448 字节。vendor 去掉 `android.hardware.bluetooth.prebuilt.xml`。没有这个特性时 SystemServer 不启动 `BluetoothService`。`pm disable` 那条命令也拿掉了。蓝牙 HAL 仍会在起来后被停掉。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `0b61a1819b1f9d7c45edadce55bcf81aec6b7902b4d24d5527a70237f26382cf`。eMMC 校验和未变。 |
| 2026-10-19 | 这次没有崩溃，也没有进入睡眠。约 203 秒 `sys.boot_completed=1`，屏幕上出现 `gru: userspace is up, console log is now quiet`，随后控制台不再刷新。systemui 约 178 秒创建，launcher3 约 184 秒创建。`vendor.hwcomposer-3` 和 minigbm 都注册了，surfaceflinger 找到了 composer。kmsg 继续到约 1539 秒，healthd 报了 32 次电量。`sbs-9-000b` 的 `current_avg` 和 `technology` 仍返回 -5，这是电量计驱动缺这两个属性，不杀进程。画面停住是因为 fbcon 还占着 DSI 面板，最后一行控制台文字盖在合成器上面。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `a0a8eb1b1c8127f3f524b98bda458a62fbd332a12584e3a37dceb529c5ba8c37`，文件 1273942448 字节。`sys.boot_completed=1` 时把 `vtcon0` 和 `vtcon1` 的 `bind` 写成 0，把帧缓冲控制台从面板上解开，扫描输出交给 `drm_hwcomposer`。控制台 loglevel 仍降到 3。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `a0a8eb1b1c8127f3f524b98bda458a62fbd332a12584e3a37dceb529c5ba8c37`。eMMC 校验和未变。 |
| 2026-10-19 | 这次没有崩溃，也没有进入睡眠。约 180 秒 `sys.boot_completed=1`。`vtcon0/bind` 写成 0 用了 226 ms 并且成功，内核立刻打印 `Console: switching to colour dummy device 80x25`。画面停在 181 秒就是这一下：帧缓冲控制台松开了，合成器没有接上，面板留着最后一帧。`vendor.hwcomposer-3` 在约 93 秒就已经启动，那时主平面还被 fbcon 占着。SystemUI 约 141 秒创建，约 157 秒 ANR（启动没在时限内完成），进程没有退出，之后还在访问 Codec2。launcher3 约 177 秒创建。kmsg 继续到约 814 秒，`sbs-9-000b` 的 `current_avg` 和 `technology` 仍返回 -5。 |
| 2026-10-19 | 新 `super.img` 已放到 `/home/user/phase3/super.img`，校验和 `4a3a5abf6ce670378d690408da67801a67ba0a6fa8a0bef9232c028e9f23ca65`，文件 1273942448 字节。解开 `vtcon0` 和 `vtcon1` 改到 post-fs，在 class hal 启动 `hwcomposer` 之前。`gru-logcat` 增加 `drmhwc:I` 和 `SurfaceFlinger:E`。内核分区不动。还没写入外置盘。上一份在 `super.img.prev`。 |
| 2026-10-19 | `write-super.sh` 打印 `WRITE_OK /dev/mmcblk0p6`。当时写入的是校验和 `4a3a5abf6ce670378d690408da67801a67ba0a6fa8a0bef9232c028e9f23ca65`。eMMC 校验和未变。 |
| 2026-10-19 | 这次有进展：post-fs 约 12.1 秒把 fbcon 解开，内核打印 `switching to colour dummy device 80x25`，所以屏幕上的日志停在 12 秒。约 91 秒 `drmhwc` 启动，约 94 秒 `DRM/KMS master access required`，接着 `No pipelines available. Creating null-display for headless mode`。合成器没有拿到 DRM master，因为内核的 fbdev 客户端从打开 `/dev/dri/card0` 起就占着 master，解开控制台不会释放它。SurfaceFlinger 从约 180 秒起报 `Invalid present fence`，到日志结束约 406 秒共 854 次，这是 headless 显示的结果。约 182 秒 `sys.boot_completed=1`。没有 zygote 退出。背光 `brightness` 的 SELinux 拒绝是 permissive。`sbs-9-000b` 的两个属性仍返回 -5。 |
| 2026-10-19 | 新 FIT 在 `/home/user/phase3/kernel.kpart`，14155776 字节，校验和 `bec010d8dd2df3a7fe275643dffbe3ca17a5aa744b30409b37c6600a66622937`。命令行增加 `drm_kms_helper.fbdev_emulation=0`，内核不再创建 fbdev 客户端，`hwcomposer` 打开 DRM 设备时可以成为 master。`depthchargectl check` 识别为 scarlet。内核没有重编。super 不动。还没写入 `KernelA`。上一份在 `kernel.kpart.prev`。 |
| 2026-10-19 | `write-kernel.sh` 打印 `WRITE_OK /dev/mmcblk0p1 14155776`。当时写入的是校验和 `bec010d8dd2df3a7fe275643dffbe3ca17a5aa744b30409b37c6600a66622937`。eMMC 校验和未变。 |
| 2026-10-19 | 这次有进展，但面板从头到尾没亮。命令行里的 `drm_kms_helper.fbdev_emulation=0` 生效了，日志里没有 `fb0`，所以不会再停在一帧控制台文字上。系统起来了：约 173 秒 `sys.boot_completed=1`，没有 zygote 退出。约 93 秒 `drmhwc` 启动，约 95 秒仍是 `DRM/KMS master access required`，接着 `No pipelines available. Creating null-display for headless mode`。`drm_fbdev_generic_setup` 在看这个参数之前就 `drm_client_init`，打开 `/dev/dri/card0` 并成为 master；参数只让后面的 `drm_fb_helper_initial_config` 跳过帧缓冲，那个文件一直开着。SurfaceFlinger 从约 153 秒到约 370 秒报了 441 次 `Invalid present fence`。SystemUI 约 149 秒 ANR（启动没在时限内完成），进程没有退出。`sbs-9-000b` 的 `current_avg` 和 `technology` 仍返回 -5。没有进入睡眠。 |
| 2026-10-19 | 新 FIT 在 `/home/user/phase3/kernel.kpart`，14155776 字节，校验和 `c9dbc41468b57362d79eda4cfd18d3415c7789e120e1b087136c845633e30529`。内核重编了：`drm_fbdev_emulation` 为 0 时 `drm_fbdev_generic_setup` 在 `drm_client_init` 之前返回，不再占着 DRM master。命令行仍是 `drm_kms_helper.fbdev_emulation=0`。vermagic 仍是 `6.6.34-phase2`。`depthchargectl check` 识别为 scarlet。super 不动。还没写入 `KernelA`。上一份在 `kernel.kpart.prev`。 |
| 2026-10-19 | `write-kernel.sh` 打印 `WRITE_OK /dev/mmcblk0p1 14155776`。当时写入的是校验和 `c9dbc41468b57362d79eda4cfd18d3415c7789e120e1b087136c845633e30529`。eMMC 校验和未变。 |
| 2026-10-19 | 这次内核已经换成了 `#2 SMP PREEMPT`，内核 fbdev 客户端不再打开 `/dev/dri/card0`，但画面本身还没有进展，面板从头到尾没亮。原因是用户空间的时序：这台机器上 `/dev/dri/renderD128` 是 `panfrost`（GPU），而 `minigbm-upstream` 里没有开启 `panfrost` 后端；`rockchip-drm` 没有 `DRIVER_RENDER`，只有主节点 `/dev/dri/card0`。约 87.9 秒 `vendor.graphics.allocator.minigbm_upstream`（以及约 91.4 秒加载 mapper 的 `surfaceflinger`）试过 `renderD128` 失败后回退打开 `/dev/dri/card0`，第一个打开者自动成为 DRM master。直到约 91.57 秒 `surfaceflinger` 才调用 `IComposer::createClient`、`registerCallback`，`vendor.hwcomposer-3` 这时才打开 `/dev/dri/card0`，已经不是第一个打开者，且没有 `CAP_SYS_ADMIN`，`drmSetMaster` 失败，`drmIsMaster` 返回 0，再次报 `DRM/KMS master access required` 并进入 headless。`SurfaceFlinger` 从约 184 秒到 332 秒报了 782 次 `Invalid present fence`。约 186 秒 `sys.boot_completed=1`，没有 zygote 退出，没有 ANR，也没有进入睡眠。`sbs-9-000b` 的两个属性仍返回 -5。 |
| 2026-10-19 | 新 FIT 在 `/home/user/phase3/kernel.kpart`，14159872 字节，校验和 `3bc8fd288d1c39eacb2e8611e3a005241c2ce145592b7d864495f5bfb2b56b68`。内核重编了：`drm_setmaster_ioctl` 允许显式调用 `DRM_IOCTL_SET_MASTER` 的 KMS 客户端（`hwcomposer`）从之前被动占着 master 的打开者（`minigbm`）手里接管 DRM master；`minigbm` 用到的 `CREATE_DUMB`/`MAP_DUMB`/`PRIME` 都不要求 `DRM_MASTER`。vermagic 仍是 `6.6.34-phase2`。`depthchargectl check` 识别为 scarlet。super 不动。还没写入 `KernelA`。上一份在 `kernel.kpart.prev`。 |
| 2026-10-19 | `write-kernel.sh` 打印 `WRITE_OK /dev/mmcblk0p1 14159872`。当时写入的是校验和 `3bc8fd288d1c39eacb2e8611e3a005241c2ce145592b7d864495f5bfb2b56b68`。eMMC 校验和未变。 |
| 2026-10-19 | 这次面板点亮，过了 `org.lineageos.setupwizard`，进入桌面和设置应用，并在约 1255 秒按用户指令正常关机（`sys.powerctl='shutdown,userrequested'`）。启动的是 `#3 SMP PREEMPT`。约 91.7 秒 `drmhwc` 拿到 DRM master，依次打印 `Attaching connector DSI-1`、`Attaching pipeline 'DSI-1' to the display #0 (Primary)`、`Backend 'generic' for 'DSI-1' and driver 'rockchip' was successfully set`。`Invalid present fence` 只在约 149 到 154 秒尚无图层（`No layers to validate` / `No layers to present`）时出现了 15 次，有图层后不再出现。约 170 秒 `sys.boot_completed=1`，没有 zygote 退出，没有进入睡眠。本次同时记录到阶段 4 需要处理的三类问题：（1）当前仍是 `TARGET_GRAPHICS := swiftshader` 纯 CPU 软渲染 `1536x2048` 且未开 zram，界面极度卡顿（约 1 到 2 秒一帧），`com.android.systemui` 在约 146 秒有一次启动超时 ANR，`com.android.settings` 在操作中有 4 次输入分发超时 ANR；（2）`device.mk` 尚未拷贝 `android.software.app_widgets.xml` 和 `android.software.backup.xml`，SystemServer 未启动 `AppWidgetService` 和 `BackupManagerService`，导致 `com.android.launcher3` 在 `launcher-loader` 线程因 `AppWidgetManager.getInstalledProvidersForProfile` 空指针崩溃重启 42 次，`com.stevesoltys.seedvault` 因 `IBackupManager` 为空崩溃 1 次；（3）有线 USB `adb` 无响应是因为 `rk3399-gru.dtsi` 里 `usbdrd_dwc3_0` 为 `dr_mode=host`，内核没有注册 UDC，且 `init.gru.rc` 停掉了 `adbd`，无线 `adb` 则要等阶段 4 配好 Wi-Fi。回到内置盘后核对：`uname -r` 仍是 `6.6.34`，根在 `/dev/mmcblk1p3`，eMMC 内核分区校验和仍是 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。阶段 3 结束。 |
