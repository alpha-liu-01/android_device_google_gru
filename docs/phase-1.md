# 阶段 1：启动契约

用内置盘上正在运行的 6.6.34 内核，把外置盘启动到一个只打印标记的 init。不挂 Debian，不挂 postmarketOS，不写 eMMC。基线在 [阶段 0](phase-0.md)。

2026-10-18 完成。外置盘启动后屏幕是黑的。回到内置盘后，`bootpart` 上的 `/gru-phase1.log` 有 `gru-android phase1` 和完整的启动日志。eMMC 内核分区校验和未变。

## 完成标准

1. 启动菜单选外置盘后，init 把 `gru-android phase1` 和内核日志写到外置盘 ext4 启动分区的 `/gru-phase1.log`。面板在进到用户空间点亮屏幕之前是黑的，不把屏幕上的字当作完成标准。
2. 再选内置盘，postmarketOS v25.06 进到图形会话。
3. eMMC 的分区表和 `pmOS_kernel` 没有被写入。

## 这次写什么

内核来自内置盘的 `/boot/vmlinuz`，设备树用 `rk3399-gru-scarlet-kd.dtb`。initramfs 里只有 `/init`：挂上 devtmpfs 和 proc，按 ext4 卷标 `bootpart` 找到外置盘的启动分区并挂上，先写入一行标记，等 8 秒后再把 `dmesg` 追加进 `/gru-phase1.log`，然后循环等待。不挂 Debian 的 btrfs 根，也不挂 eMMC。

depthcharge 板名 `gru`，压缩 lzma。命令行是 `kern_guid=%U console=tty0 loglevel=7 deferred_probe_timeout=30`。没有 `root=`、`pmos_root_uuid` 或 `quiet`。构建时加 `--root none`，否则工具会把当时系统的根 UUID 写进命令行。

外置盘有两个 32 MiB 的内核槽，`KernelA` 和 `KernelB`。只写 depthcharge 实际会启动的那一个，另一个留着。`bootpart` 和 `rootpart` 不动，Debian 的文件还在，但选外置盘之后进不了 Debian，直到这个内核槽被换回去。

不要在内置盘上试休眠。6.6 上尝试休眠会整机崩溃并停在 bootloader。

## 你来做

1. 从启动菜单选内置盘，进到 postmarketOS 桌面。上次地址是 `user@10.0.0.133`。地址变了就告诉我。
2. 确认可以改外置盘上 depthcharge 正在用的那个内核槽。Debian 的根分区还在，选外置盘时不再进 Debian。
3. 我写入时如果 `doas` 或 `sudo` 要密码，在机器上输入。我看不到这个密码。
4. 我说镜像已经写好之后：重启，菜单选外置盘。屏幕会一直是黑的。等大约一分钟，再重启，选内置盘。
5. 回到内置盘后确认 v25.06 还在桌面，把地址告诉我。日志在外置盘的启动分区上，我来读。

外置盘起不来、黑屏或回到选盘菜单时，重启改选内置盘。内置盘的内核分区这次不会写。

## 我来做

你停在内置盘、我能 SSH 进去之后：

1. 确认 `uname -r` 是 `6.6.34`，根分区是 `mmcblk1p3`，外置盘是 `mmcblk0` 且没有被挂成 `/`。对不上就停止。
2. 读两个内核槽的优先级和成功次数，确定这次写哪一个。目标如果是 `mmcblk1` 或当前启动盘，不写。
3. 用内置盘的 `/boot/vmlinuz`、`rk3399-gru-scarlet-kd.dtb` 和上面的 initramfs 打 depthcharge 镜像。`depthchargectl check` 通过后再写。
4. 只写第 2 步确定的那个外置盘内核分区，使用 `--no-prioritize`。写入前后核对 eMMC `pmOS_kernel` 的校验和，并核对分区起止没变。
5. 你选过外置盘、再回到内置盘之后，核对 eMMC 仍然是 v25.06，根分区仍是 `mmcblk1p3`。

## 实现顺序

| 步 | 谁 | 做什么 | 通过条件 |
| --- | --- | --- | --- |
| 1 | 你 | 停在内置盘，并确认可以改外置盘的内核槽 | SSH 上是 6.6.34，根在 `mmcblk1p3` |
| 2 | 我 | 确认内核槽，打好镜像 | 镜像还没写盘，eMMC 校验和已记下 |
| 3 | 我 | 只写外置盘的那个内核槽 | eMMC 内核分区校验和不变 |
| 4 | 你 | 菜单选外置盘，等大约一分钟，再选回内置盘 | v25.06 进桌面；外置盘启动分区上有 `/gru-phase1.log` |
| 5 | 我 | 读这份日志，并再核对内置盘 | 日志里有 `gru-android phase1`；根在 `mmcblk1p3`，eMMC 内核分区校验和仍不变 |

第 4 步屏幕是黑的，这是预期。第 4 步和第 5 步都对上之后，阶段 1 结束。

## 实现笔记

2026-10-18 从内置盘确认：`uname -r` 为 `6.6.34`，根分区 `/dev/mmcblk1p3`，`/boot` 是 `/dev/mmcblk1p2`，外置盘是 `mmcblk0`（SD64G），没有挂成 `/`。发行版是 postmarketOS v25.06。

镜像在 `/home/user/phase1/kernel.kpart`，7,770,112 字节，sha256 `727b11879a34abc275d672d7657e84f4e0db55d85ba4aa51321f0f287373a794`。内核是 `/boot/vmlinuz`，设备树是 `rk3399-gru-scarlet-kd.dtb`，initramfs 只含 `/init`、busybox 和 musl。`depthchargectl check` 通过，板识别为 scarlet（Acer Chromebook Tab 10），并打印检查不完整。命令行是 `kern_guid=%U console=tty0 loglevel=7 deferred_probe_timeout=30`。

写入脚本是 `/home/user/phase1/write.sh`。外置盘 `KernelA`（`mmcblk0p1`）priority=10、successful=1，是 depthcharge 会启动的槽。`KernelB` priority=0。第一次运行把输出只写进日志，并且没解析出分区，打印 `ABORT_PARSE` 后退出，没有写盘。脚本已改为在终端显示输出。第二次写入 `/dev/mmcblk0p1`，打印 `WRITE_OK /dev/mmcblk0p1 7770112`。分区表未改。镜像字节与分区开头一致。

选外置盘后面板一直是黑的。这块板在进到用户空间点亮屏幕之前不显示控制台，Debian 启动时也是这样。`console=tty0` 的标记看不到。第一次的 init 没有挂任何分区，内核日志只在内存里。`/sys/fs/pstore` 不存在，系统里没有 `cbmem`。

之后的测试都把启动日志写到外置盘 ext4 启动分区的 `/gru-phase1.log`。第二份镜像已写入 `/dev/mmcblk0p1`，`WRITE_OK /dev/mmcblk0p1 7770112`。sha256 `55c6de1af7a7fb79efe22242d34e49a94dab9103f74880e35972462b0805fec5`，与分区开头一致。eMMC `pmOS_kernel` 写入前后都是 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。eMMC 和外置盘的分区表都没变。init 按卷标 `bootpart` 挂上该分区，写入标记和 `dmesg`。

第二次选外置盘后面板仍是黑的。回到内置盘后，根仍是 `/dev/mmcblk1p3`，内核仍是 `6.6.34`。`/gru-phase1.log` 有 24509 字节。文件时间是 1969-12-31，因为这次 init 没有设置时钟。日志里机器型号是 `Google Scarlet`，内核是 `6.6.34 #7-postmarketos-rockchip`。命令行是 `cros_secure kern_guid=73b52be6-095d-9843-a584-d00cc11dcb63 console=tty0 loglevel=7 deferred_probe_timeout=30`，这个 GUID 就是外置盘 `KernelA`。`[0.889617] Run /init`，`[0.899298] gru-android phase1`。`[1.930124]` 把 `mmcblk0p3`（UUID `d287033f-58c4-4cee-831b-654b75fe6487`）以读写挂上，没有 journal。日志以 `=== end ===` 结束，没有 panic 或 Oops。回到内置盘后 eMMC 校验和仍是 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。

日志开头的 `--- version ---` 和 `--- cmdline ---` 是空的。initramfs 里没有 `/proc` 目录，proc 没挂上；`dmesg` 不依赖 proc，命令行在内核日志里。VOP 和 DSI 只有依赖环的提示，这次 init 不会点亮面板。`hid_bpf` 的 `-22` 和 `cacheinfo: Unable to detect cache hierarchy` 没有让启动停住。

## 事件

| 日期 | 事件 |
| --- | --- |
| 2026-10-18 | 内置盘是 6.6.34，根在 mmcblk1p3。打出 `kernel.kpart`，检查识别为 scarlet。 |
| 2026-10-18 | 第一次 `write.sh` 以 `ABORT_PARSE` 退出。`KernelA` 是启动槽。外置盘未写。 |
| 2026-10-18 | 写入 `/dev/mmcblk0p1`，`WRITE_OK`，7770112 字节。eMMC 校验和与分区表未变。 |
| 2026-10-18 | 选外置盘后面板全黑。回到内置盘后，这次启动没有留下可读取的内核日志。 |
| 2026-10-18 | 第二份镜像写入 `/dev/mmcblk0p1`，`WRITE_OK`。日志目标是 `bootpart` 的 `/gru-phase1.log`。eMMC 校验和与分区表未变。 |
| 2026-10-18 | 选外置盘后面板全黑。回到内置盘后读到 `/gru-phase1.log`：Scarlet、6.6.34、`gru-android phase1`、`bootpart` 已挂上。eMMC 校验和未变。阶段 1 完成。 |
