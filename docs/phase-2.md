# 阶段 2：Android 内核配置

在内置盘这颗 `linux-postmarketos-rockchip` 6.6.34-r6 上补 Android 需要的配置，再用它启动外置盘上现有的 Debian 用户空间。不装 Android，不换 6.12 或 6.18，不写 eMMC。阶段 1 的记录在 [阶段 1](phase-1.md)。

产品形态以 `third_party/android_device_google_trogdor-lineage-24` 为准。那是另一位开发者做完并且能用的 Trogdor 设备树。`third_party/failed_docs` 是这棵 23.2 树上 Trogdor 停在亮屏前的笔记，只用来避开已经发生过的内核故障。两边不一致时，跟做完的设备树。

2026-10-18 完成。外置盘的 Debian 13 用 `6.6.34-phase2` 进到 XFCE。回到内置盘后仍是 postmarketOS v25.06，eMMC 内核分区校验和未变。

## 完成标准

1. 启动菜单选外置盘后，进入 SD 上的 Debian。`uname -r` 以 `6.6.34` 开头，并带这次的本地版本标记。画面、触摸、Wi-Fi 仍可用。
2. 再选内置盘，postmarketOS v25.06 进到图形会话。eMMC 的分区表和 `pmOS_kernel` 没有被写入。

休眠不作为这一段的通过条件。6.6 上尝试休眠会整机崩溃，下次启动停在 bootloader。耳机插孔是物理损坏，不测。

面板在用户空间点亮屏幕之前是黑的。Debian 桌面起来之后应该有画面。若选外置盘后大约一分钟仍然全黑，回到内置盘，启动日志在 `bootpart` 的 `/gru-phase2.log`。

## 这次做什么

内核版本留在 6.6.34-r6。源码和配置向 postmarketOS v25.06 的这个包取，不用 `third_party/pmaports-main` 里的 7.2.9，也不用 `third_party/old` 里的 6.12.57。本地版本字符串是 `-phase2`。6.12 那块 Kingdisplay 的 EoTp 补丁不打。

配置只增加选项。LineageOS 23.2 的 Android 基础清单里写成 `=y`、6.6.34 源码里又存在、而当前配置没有打开的项，加进片段。源码里没有的符号不加，包括 Rust binder、`CONFIG_ASHMEM`、`CONFIG_CPUSETS_V1`。不关清单里标成未设置的项，Debian 和 postmarketOS 的用户空间还要能用。不打开 `CONFIG_CFI_CLANG` 和 `CONFIG_SHADOW_CALL_STACK`。

做完的 Trogdor 树决定后面的镜像要挂什么。`fstab.trogdor` 里 system、vendor、system_ext、product 和两个 dlkm 都是 erofs，并且 `first_stage_mount`。userdata 是 f2fs，带文件加密；metadata 是 ext4。命令行有 `androidboot.selinux=permissive` 和 `deferred_probe_timeout=30`，没有 `binder.impl=rust`。因此这颗内核至少要编进：

| 选项 | 现在的 6.6.34 | 这次 |
| --- | --- | --- |
| `CONFIG_EROFS_FS` | 没有 | 编进内核。first stage 挂 erofs 之前不能靠再加载模块 |
| `CONFIG_SECURITY_SELINUX`、`CONFIG_SECURITYFS`、`CONFIG_SECURITY_NETWORK` | 没有 | 编进内核。Android 那次启动再加 `security=selinux` |
| `CONFIG_ANDROID_BINDERFS` | 没有 | 打开。`CONFIG_ANDROID_BINDER_IPC` 已经编进内核，继续用 C binder |
| `CONFIG_USB_CONFIGFS_F_FS` | 没有 | 打开。`CONFIG_USB_DWC3` 已经编进内核，`CONFIG_USB_CONFIGFS` 现在是模块 |
| `CONFIG_BLK_DEV_DM` | 模块 | super 的逻辑分区要在 first stage 可用。能编进内核就编进内核 |
| netd 要用的 netfilter | `CONFIG_NF_TABLES` 等是模块 | 基础清单写成 `=y` 的改成编进内核；清单本身就是模块的先留着，阶段 3 的 ramdisk 必须在 `netd` 之前加载 |
| `CONFIG_EXT4_FS`、`CONFIG_F2FS_FS`、`CONFIG_FS_ENCRYPTION` | 已经编进内核 | 保持 |
| `CONFIG_BTRFS_FS` | 模块 | 保持为模块，但放进这次的 initramfs。Debian 的根是 btrfs |

`BOARD_SUPER_PARTITION_SIZE`、高通用户空间、Freedreno、`minigbm` 的 msm platform、Trogdor 的音频策略和 IDC 都不进这颗内核，也不进阶段 2 的验证镜像。

验证用的用户空间是外置盘上的 Debian 13，根分区标签 `rootpart`，不是 postmarketOS，也不是阶段 1 那个只写标记的 init。Debian 原来的 initramfs 是按 `6.18.34-stb-cbg+` 打的，不能原样套上 6.6.34。Trogdor 阶段 2 第一次就是这样停在 initramfs 里的。这次的 initramfs 带上这颗内核自己的模块，至少包括挂上 btrfs 根所需要的那些，并且仍然把启动日志写到 `bootpart`。其余模块装进 Debian 根分区的 `/lib/modules`，不删原来的 6.18 模块，也不写内置盘的 `/lib/modules`。

内核分区仍是 32 MiB。FIT 装不下时，initramfs 里只留挂根和写日志需要的模块，不加大分区。

depthcharge 板名 `gru`，压缩 lzma，设备树 `rk3399-gru-scarlet-kd.dtb`。构建时加 `--root none`，再自己写上 Debian 根的标识。不能把正在运行的 postmarketOS 根 UUID 带进命令行。只写外置盘 `KernelA`（`mmcblk0p1`），`--no-prioritize`。`KernelB` 不动。

## 你来做

1. 从启动菜单选内置盘，进到 postmarketOS 桌面。上次地址是 `user@10.0.0.133`。地址变了就告诉我。
2. 确认可以再次改外置盘的 `KernelA`，并可以往 Debian 的根分区里加一份 `6.6.34-phase2` 的模块目录。不格式化 SD，不删除原来的 6.18 模块。选外置盘时，在这颗新内核启动成功之前，仍然进不了 Debian。
3. 我挂载 SD 或写入内核分区时，如果 `doas` 或 `sudo` 要密码，在机器上输入。我看不到这个密码。
4. 我说镜像已经写好之后：重启，菜单选外置盘。桌面出现的话，看画面、触摸和 Wi-Fi，把 `uname -r` 和 SSH 地址告诉我。不要休眠。
5. 大约一分钟后仍然全黑：重启，改选内置盘，把地址告诉我。日志我来读。
6. 外置盘确认完之后再重启回内置盘，确认 v25.06 还在桌面。

外置盘起不来或回到选盘菜单时，重启改选内置盘。内置盘的内核分区这次不会写。

## 我来做

你停在内置盘、我能 SSH 进去之后：

1. 确认 `uname -r` 是 `6.6.34`，根分区是 `mmcblk1p3`，外置盘是 `mmcblk0` 且没有被挂成 `/`。对不上就停止。
2. 取出 v25.06 的 6.6.34-r6 源码和配置，对照 23.2 的 Android 基础清单和上面这张表。差距写进实现笔记，还没编译就停下来核对。
3. 只增加缺少的选项，在工作站编出内核和模块。本地版本是 `-phase2`。
4. 做 initramfs：能挂上 Debian 的 btrfs 根，并把 `gru-android phase2` 和 `dmesg` 写到 `bootpart` 的 `/gru-phase2.log`。不使用 Debian 原来那份 6.18 的 initramfs。
5. 模块装进外置盘 Debian 根的 `/lib/modules`。eMMC 的模块目录不动。
6. `depthchargectl check` 通过后，只写 `/dev/mmcblk0p1`，`--no-prioritize`。目标如果是 `mmcblk1` 或当前启动盘，不写。写入前后核对 eMMC `pmOS_kernel` 的校验和，并核对分区起止没变。
7. 你选过外置盘、再回到内置盘之后，读 `/gru-phase2.log`，并核对根仍是 `mmcblk1p3`、eMMC 校验和未变。

## 实现顺序

| 步 | 谁 | 做什么 | 通过条件 |
| --- | --- | --- | --- |
| 1 | 你 | 停在内置盘，并确认可以改 `KernelA` 和 Debian 根里的模块目录 | SSH 上是 6.6.34，根在 `mmcblk1p3` |
| 2 | 我 | 对照清单，写出配置差距 | 差距在实现笔记里，还没编译 |
| 3 | 我 | 编出 `6.6.34-phase2` 和模块 | 本地版本标记能和发行版内核区分 |
| 4 | 我 | 模块放上 Debian 根，内核分区只写 `mmcblk0p1` | FIT 不超过 32 MiB；eMMC 内核分区校验和不变 |
| 5 | 你 | 菜单选外置盘 | Debian 起来，画面、触摸、Wi-Fi 可用，`uname -r` 是这颗 6.6.34 |
| 6 | 你 | 菜单选回内置盘 | v25.06 进桌面 |
| 7 | 我 | 读 `/gru-phase2.log`，再核对内置盘 | 根在 `mmcblk1p3`，eMMC 内核分区校验和仍不变 |

第 5 步若一直黑屏，先回到内置盘，用第 7 步的日志判断停在哪里，不把黑屏本身当成失败。第 5 步到第 7 步都对上之后，阶段 2 结束。

## 实现笔记

2026-10-18 从内置盘确认：`uname -r` 为 `6.6.34`，根分区 `/dev/mmcblk1p3`，`/boot` 是 `/dev/mmcblk1p2`，外置盘是 `mmcblk0`，没有挂成 `/`。

源码是 kernel.org 的 `linux-6.6.34.tar.xz`，sha512 与 v25.06 的 APKBUILD 一致。这份 APKBUILD 没有额外补丁。配置文件 sha512 也与 APKBUILD 一致。本地版本是 `-phase2`，`kernel.release` 为 `6.6.34-phase2`。

6.6.34 里没有这些符号，不加：`ASHMEM`、`CPU_FREQ_TIMES`、`DM_DEFAULT_KEY`、`NETFILTER_XT_MATCH_QUOTA2`、`NETFILTER_XT_MATCH_QUOTA2_LOG`、`UID_SYS_STATS`、`TRACE_GPU_MEM`。没有 Rust binder。

没有打开的项：`CONFIG_STATIC_USERMODEHELPER`（会去找发行版没有的 usermode helper，固件加载会断）、`CONFIG_DEFAULT_SECURITY_SELINUX`、`CONFIG_CFI_CLANG`、`CONFIG_SHADOW_CALL_STACK`。`CONFIG_LSM` 保持空字符串，这次 Debian 启动不把 SELinux 设成默认。`CONFIG_SECURITY_SELINUX_DEVELOP` 打开后，即使以后加上 `security=selinux`，默认也是 permissive。`CONFIG_BTRFS_FS` 和 `CONFIG_NF_TABLES` 仍是模块。`CONFIG_INET_UDP_DIAG` 因为上级仍是模块，保持为模块。

`olddefconfig` 之后编进内核的有：`CONFIG_EROFS_FS`（含 zip）、`CONFIG_SECURITY_SELINUX`、`CONFIG_SECURITYFS`、`CONFIG_SECURITY_NETWORK`、`CONFIG_ANDROID_BINDERFS`、`CONFIG_USB_CONFIGFS_F_FS`、`CONFIG_BLK_DEV_DM`、`CONFIG_DM_SNAPSHOT`、`CONFIG_DM_VERITY`、`CONFIG_BLK_INLINE_ENCRYPTION`、`CONFIG_FS_ENCRYPTION_INLINE_CRYPT`。ext4、f2fs、`FS_ENCRYPTION` 本来就是编进内核。`CONFIG_USB_CONFIGFS`、`CONFIG_DM_CRYPT`、面板和 Panfrost 仍是模块。

`CONFIG_EXPERT=y` 使 `CONFIG_MEDIA_HIDE_ANCILLARY_SUBDRV` 不能再为 y。原先是模块的媒体驱动没有被关掉。

工作站没有 root，交叉编译器用的是 conda-forge 的 `aarch64-conda-linux-gnu-gcc` 14.4.0。发行版内核是 Alpine gcc 14.2.0 编的。

内核和模块已编出。`arch/arm64/boot/Image` 24 MiB，gzip 后的 `vmlinuz` 9.2 MiB。模块树 19 MiB，装在设备的 `/home/user/phase2/modules`，还没写进 Debian 根。initramfs 1.7 MiB，里面有 busybox、musl，以及未压缩的 `xor-neon`、`xor`、`raid6_pq`、`btrfs`。它按卷标 `rootpart` 挂 btrfs，把 `gru-android phase2` 和 `dmesg` 写到 `bootpart` 的 `/gru-phase2.log`，再 `switch_root` 到 `/sbin/init`。不用 Debian 原来的 6.18 initramfs。

`kernel.kpart` 9,060,352 字节，sha256 `147ed44f2a937a7a983c1c69a3683a0bb520fabdcf75c3cb361a2c04a90f66c0`。`depthchargectl check` 识别为 scarlet。命令行是 `kern_guid=%U console=tty0 loglevel=7 deferred_probe_timeout=30 root=LABEL=rootpart rootfstype=btrfs rw`，没有 postmarketOS 的根 UUID。小于 32 MiB。

`install.sh` 把 Debian 根的默认子卷挂上，`/sbin/init` 在。模块目录里原来的 `6.18.34-stb-cbg+` 还在，旁边多了 `6.6.34-phase2`。然后写入 `/dev/mmcblk0p1`，`WRITE_OK`。分区开头的校验和与镜像一致。eMMC `pmOS_kernel` 仍是 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。eMMC 和外置盘的分区表都没变。Debian 的 fstab 用 `LABEL=rootpart` 和 `LABEL=bootpart`，和 initramfs 的找盘方式一致。

选外置盘后 Debian 13 进入 XFCE。`uname -a` 为 `Linux changeme 6.6.34-phase2 #1 SMP PREEMPT Sun Oct 18 20:32:14 EDT 2026 aarch64`，根是 `/dev/mmcblk0p4` btrfs。面板是 DSI-2 `1536x2048 @ 60 Hz`。`wlp1s0` 已拿到 `10.0.0.115/24`。输入设备里有 `Elan Touchscreen` 和 `hid-over-i2c 2D1F:0036`。`/boot/gru-phase2.log` 有 `gru-android phase2`，`rootpart=/dev/mmcblk0p4`，`how=default`，`/sbin/init` 指向 systemd。命令行里的 `kern_guid` 是外置盘 `KernelA`。运行中的配置里 erofs、SELinux、`SECURITYFS`、binderfs、`USB_CONFIGFS_F_FS` 和 `BLK_DEV_DM` 都是编进内核；`CONFIG_LSM` 仍是空的；`NF_TABLES` 和 btrfs 仍是模块。没有 panic 或 Oops。

## 事件

| 日期 | 事件 |
| --- | --- |
| 2026-10-18 | 内置盘是 6.6.34，根在 mmcblk1p3。源码和配置与 v25.06 的 6.6.34-r6 一致。配置片段已合入。 |
| 2026-10-18 | 编出 `6.6.34-phase2`。`kernel.kpart` 9060352 字节，检查识别为 scarlet。 |
| 2026-10-18 | 模块写入 Debian 根，`6.18.34-stb-cbg+` 仍在。`WRITE_OK /dev/mmcblk0p1`。eMMC 校验和与分区表未变。 |
| 2026-10-18 | 外置盘进入 Debian 13 XFCE。`uname` 为 `6.6.34-phase2`，画面 `1536x2048`，Wi-Fi 为 `10.0.0.115`。Elan 触摸和 Wacom 笔的输入设备在。日志在 `/boot/gru-phase2.log`。 |
| 2026-10-18 | 回到内置盘。`uname` 为 `6.6.34 #7-postmarketos-rockchip`，根在 `mmcblk1p3`，v25.06。eMMC 校验和仍是 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。阶段 2 完成。 |
