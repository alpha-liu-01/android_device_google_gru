# 阶段 0：基线

2026-10-18 结束。机器身份、分区和两套系统的其余记录在 [路线图](roadmap.md)。外置盘是 [velvet-os imagebuilder 的 chromebook_gru](https://github.com/velvet-os/imagebuilder/tree/main/systems/chromebook_gru)，内核 `6.18.34-stb-cbg+`。eMMC 未写。

扬声器、Wi-Fi、蓝牙、触摸和 Wacom 电磁笔在这台上可用。耳机插孔是物理损坏。

## 外置盘 6.18 的休眠

2026-10-18 你在 Debian 上做了休眠。内核记了两次 deep，`suspend_stats` 是 `success=2`、`fail=0`。两次都回到了同一次启动，没有被看门狗复位。CPU 没有停住。

| | 第一次 | 第二次 |
| --- | --- | --- |
| 进入 | 内核时间 173.143 秒 | 1013.797 秒 |
| 退出 | 174.927 秒 | 1015.688 秒 |
| 非启动 CPU 关掉的时间 | 约 15 毫秒 | 约 15 毫秒 |
| 整段耗时 | 1.8 秒 | 1.9 秒 |

第二次进入之前，`wlan0` 主动断开，`btusb` 被卸掉，这是休眠前的正常准备。非启动 CPU 关掉后大约 15 毫秒就又被拉起来。屏幕黑一下再亮，看起来像唤醒成功，实际没有进入保持住的休眠。

`cros-ec-rtc` 的 `event_count` 是 2，和这两次休眠次数相同。`dw_wdt` 停不下来，内核大约每 10 秒打一行 `watchdog0: watchdog did not stop!` 并自己去喂。这行从启动后约 180 秒一直打到检查时，机器没有因此重启。

这和内置盘 6.6 的故障不是同一件事。6.18 这次是休眠路径立刻返回。6.6 是一尝试休眠，整机崩溃，下次上电停在 bootloader。

`mem_sleep` 仍是 `deep`。`RuntimeWatchdogSec` 仍是关闭。这项不用再做一次同样的操作。

## 内置盘 6.6 的休眠

6.6.34 上尝试休眠会让整机崩溃，下次启动直接进 bootloader。这不是屏幕熄灭再亮起。

[c49c00d](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/commit/c49c00d09d1c9e266bd8c8e8ddae6e7255a5ee94) 的 `RuntimeWatchdogSec=30` 解决的是这次崩溃。`dw_wdt` 在休眠恢复后还要有人喂，否则机器死在 bootloader。它不解决 6.18 上那种 15 毫秒就回来的休眠。当前 postmarketOS 是 `device-google-gru-8-r2`，没有这份配置。

不再在这台 6.6 上做休眠试验。Android 镜像从第一份开始就要自己喂 `/dev/watchdog`，超时 30 秒，恢复之后立刻继续喂。这样 6.6 上的休眠才不会把机器打进 bootloader。

## 电池

电池硬件是好的。Debian 6.18 上充电正常，也没有电量突然变成 0 的情况。这两条只出现在内置盘的 postmarketOS 上：

- 充电一段时间后，机器自己断电。
- 离电使用时会突然报警电量为 0。插上电源后又回到大约 60% 到 70%。

这不是换电池能解决的，也不是 6.18 内核的充电故障。Android 若继续用 6.6，电量计不能照抄 postmarketOS 现在的读数。阶段 4 要对照的是插上之后电量回到的那个值，而不是报警时的 0。
