# 已知问题

实机是 Scarlet（Acer Chromebook Tab 10），系统是 microSD 上的 LineageOS 23.2。这里只记已经复现过的问题。USB 音频走的是另一块 `snd-usb-audio` 控制器，下面这条和它无关。

| 编号 | 状态 | 现象 |
| :--- | :--- | :--- |
| 1 | 已在本次启动中验证，重启后要靠新的 `vendor` 镜像才保留 | 睡眠唤醒后内置扬声器没声音 |

## 1. 睡眠唤醒后内置扬声器没声音

- **现象**：开机后内置扬声器正常。进入 S3 再唤醒，按键音、媒体音都没有。USB 耳机（`card 1`）仍然正常。
- **日志与实测（`10.0.0.110`，2026-10-21）**：
  - `AudioFlinger` 的内置输出线程 `AudioOut_D`（`AUDIO_DEVICE_OUT_SPEAKER`，`CARD_0_DEV_0`）在唤醒后仍然按实时速度写出有幅度的 PCM。这不能证明喇叭在响：`StreamPrimary` 用 `usleep` 自己节流，硬件时钟停了界面也还是按秒走。
  - 直接 `tinyplay2` 播 3 秒 48 kHz 立体声，唤醒后大约 **0.53 秒**就写完。按采样点算大约是 48 kHz 的 6.5 倍，等于 `80000000 / (4 × 64)`。RK3399 的小数分频器在分母没有按「分子的 20 倍」锁住时，硬件会退回 `parent/20`，`clk_i2s0_div` 的 1.6 GHz 父时钟除以 20 就是 **80 MHz**。
  - `/sys/kernel/debug/clk` 里 `clk_i2s0` 仍显示 `12288000`，`CLKSEL_CON(96)` 读出来的分子/分母也还是休眠前的 `24/3125`。时钟框架认为速率没变，`clk_set_rate()` 同一个值是空操作，不会把 CRU 的锁存再写一遍。I2S 的 `CKR` 按 12.288 MHz 配了 `div 4 / 64`，实际主时钟却是 80 MHz，所以 LRCK 变成大约 312.5 kHz，喇叭等于听不到。
  - 停流时 `I2S_CLR` 要等主时钟自己清掉。主时钟不对时轮询 200 µs 超时（`-110`，`fail to clear` / `lrclk update failed`）。这个错误原来会让 `soc_dai_trigger` 失败，之后每次打开都还是静音。
- **修复**（`patches/kernel_6.6.34_rockchip_i2s_s3_mclk.patch`，模块 `snd-soc-rockchip-i2s.ko`）：
  1. `runtime_resume` 里先把 mclk 设成一半再设回原来的速率，强迫 CRU 重新锁存；同时 `disable`/`enable` 一次，把被 S3 复位的门控写回去。设备如果休眠时还处于 runtime active，走 `SET_SYSTEM_SLEEP_PM_OPS` 的 resume 做同样的事。
  2. 先停 `XFER` 再清 FIFO，轮询放宽到 5 ms。超时只打警告，不再让 DAI trigger 失败。BCLK 引脚改到清 FIFO 之后再切成 GPIO。resume 时写一次 `I2S_CLR = 0`，清掉已经卡住的清除位。
- **实机**：新模块载入后，`suspend_stats/success` 从 2 增到 3 的那次唤醒之后，连续两次 `tinyplay2` 都是 **3.05 秒 / 3.04 秒**，没有新的 `fail to clear`。当前这次启动已经在用新模块，可以直接再睡一次试喇叭。重启后要靠下面这份镜像，旧的 `/vendor/lib/snd-soc-rockchip-i2s.ko` 还是坏的。
- **新发布包**：`lineage-23.2-gru-20261021.zip`，`1,038,695,940` 字节，SHA-256 `37e69acbed7bc32b9242e76e3a38404672e9961708456e907e7157da4a27c61d`。
