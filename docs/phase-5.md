# 阶段 5：仓库公开化整理与可分发 SD 镜像打包方案

## 1. 目标与完成标准

阶段 5 的核心目标有两项：
1. **仓库公开化（GitHub Release Ready）**：将当前 `android_device_google_gru` 仓库整理为结构自洽、无本地硬编码路径、无缺失构建产物、许可证清晰的公开 GitHub 仓库，使任何开发者克隆后均可按 `README.md` 复现完整构建。
2. **一键刷写的可分发 SD 镜像（Distributable Image）**：提供宿主机端全自动打包脚本，生成兼容 **Windows Rufus**、**BalenaEtcher** 与 Linux/macOS `dd` 的标准 `.zip`（内含完整 ChromeOS GPT 分区表的 `.img` 裸盘镜像），支持插入任何容量（16 GB 及以上）的 microSD 卡通过 `Ctrl + U` 直接启动，并在首次开机时自动将 `userdata` 分区扩容至整张 SD 卡容量，且**完全不触碰机器内置 eMMC（保留原有的 postmarketOS 或 ChromeOS）**。

**完成标准**：
- 仓库在无本地未跟踪文件依赖的情况下可通过 `apply-patches.sh` 完成 `m superimage` 与完整发布包构建。
- 从零使用 BalenaEtcher 或 Rufus 将生成的 `lineage-23.2-gru-YYYYMMDD.zip` 写入一张 microSD 卡，插入开启开发者模式的 `scarlet-kd` 按 `Ctrl + U` 直接启动进入 Android 16 桌面，`userdata` 自动扩容至整卡剩余空间，eMMC 上的 postmarketOS 完好无损。

---

## 2. 当前仓库公开化审查（GitHub Readiness Audit）

对比 YAJATapps 的 Google Trogdor 仓库体系（拆分为 `android_local_manifest_google_trogdor`、`android_device_google_trogdor`、`android_vendor_google_trogdor` 三个仓库 + `patches.sh` 用 `sed` 原地修改源码）与我们当前的 `android_device_google_gru` 单体仓库（Monorepo）：

### 2.1 仓库架构评估：单体仓库（Monorepo） vs 多仓库拆分

当前 `android_device_google_gru` 采用 **All-in-One 单体仓库** 设计：
- `device/google/gru/`：Android 设备树、板级配置、无线/蓝牙/DP 固件（`firmware/`）及 vendor 内核模块（`modules/*.ko`）。
- `local_manifests/gru.xml`：主线图形栈与多媒体依赖清单（`drm_hwcomposer`、`mesa`、`minigbm-upstream`、`device/mainline/common` 等）。
- `patches/`：19 个针对 LineageOS 23.2 的标准 `.patch` 补丁文件、4 个针对 Linux `6.6.34` 的内核补丁，以及幂等脚本 `apply-patches.sh`（使用 `patch --dry-run` 校验，比 Trogdor `patches.sh` 的 `sed -i` 更稳健、可逆且易于代码审查）。
- `kernel/`：Linux `6.6.34-phase2` 完整 `.config` 与配置片段。
- `docs/`：从阶段 0 到阶段 5 的完整工程记录与排障文档。

**结论**：当前单体仓库的组织方式**非常适合直接公开到 GitHub**，用户只需克隆一个仓库即可获得设备树、补丁、内核配置、预编译模块与打包工具，无需维护多仓库分支同步。

### 2.2 公开前必须修复的 5 项问题

经过对当前 Git 跟踪状态（`git status --ignored` 与 `git ls-files`）的全面排查，发现以下 5 项在公开及打包前需清理的问题：

| 序号 | 问题定位 | 影响说明 | 修复方案 |
| :--- | :--- | :--- | :--- |
| **1** | **`device/google/gru/.gitignore` 忽略了 `modules.mk` 与 `prebuilt/`** | **阻断外部构建（Critical）**：`device.mk` 第 279 行包含 `include $(LOCAL_PATH)/modules.mk`，且 `modules.mk` 引用了 `prebuilt/6.6.34-phase2/*.ko`（87 个早期 ramdisk 模块及 `rk3399-gru-scarlet-kd.dtb`，共约 2.8 MB），`wrap-ramdisk.sh` 引用了 `prebuilt/gru-keep`、`watchdog.ko`、`dw_wdt.ko`。因为它们被 `.gitignore` 忽略而未入库，外部用户克隆仓库后执行 `m superimage` 会直接报错 `modules.mk: No such file or directory`。 | 从 `device/google/gru/.gitignore` 中移除 `modules.mk` 和 `prebuilt/`，将 `modules.mk`、`prebuilt/6.6.34-phase2/`、`prebuilt/watchdog.ko`、`prebuilt/dw_wdt.ko`、`prebuilt/gru-keep` 以及预编译内核 `Image` / 全套 `rk3399-gru-*.dtb` 纳入 Git（或 Git LFS / Release Assets）管理，实现开箱即构建。 |
| **2** | **早期调试刷机脚本含本地硬编码路径与特定卡校验** | `device/google/gru/` 下的 `write.sh`、`write-kernel.sh`、`write-loopfix.sh`、`write-super.sh`、`readlog.sh` 硬编码了 `/home/user/phase3`、特定 64 GB SD 卡字节数（`62549655552`）及开发者个人机器 eMMC 的 SHA-256（`5c188eeb7a89...`）；`wrap-ramdisk.sh` 默认路径指向 `/run/media/alpha/YMTC/...`。 | 将阶段 3 专用的设备端调试脚本归档至 `device/google/gru/tools/bringup/`（或清理），并在 `device/google/gru/tools/` 下提供通用的宿主机打包脚本 `pack_kpart.sh` 与 `pack_release_image.sh`，统一使用 `$ANDROID_BUILD_TOP` 与相对路径。 |
| **3** | **Git 分支命名** | 当前工作分支名为 `no-mtp`（阶段 4 临时分支名）。 | 在完成阶段 5 整理后，将主分支规范化为 `lineage-23.2`（或 `main`）并设为 GitHub 默认分支。 |
| **4** | **缺少根目录 `LICENSE` 文件** | 仓库包含 Apache-2.0（Android 设备树配置）、GPL-2.0（Linux 内核补丁与 `.ko` 模块）以及 `linux-firmware` 可重分发固件（`QCA6174`、`qca`、`rockchip/dptx.bin`）。 | 添加根目录 `LICENSE` 并在 `README.md` 声明各目录组件对应的开源/固件许可协议。 |
| **5** | **`gru-keep` 对 `bootlog` 分区的 45 秒等待逻辑** | `gru-keep.c` 在启动 Android `init` 前会循环最多 45 秒等待 `PARTNAME=bootlog`。若分发镜像的 GPT 表不含 `bootlog` 分区，每次开机会白白卡顿 45 秒。 | 在发布镜像的 GPT 分区表中保留一个 16 MB 的 `bootlog`（`ext4`）分区供排障记录；同时优化 `gru-keep.c`，当 `super` 分区已就绪且 `bootlog` 不存在时不作多余阻塞等待。 |

---

## 3. 镜像分发方案设计：为什么选择 Trogdor 的 `.zip`（内含 GPT `.img`）方案？

### 3.1 Windows Rufus 与 BalenaEtcher 兼容性分析

Yajat Kumar 在 Google Trogdor Chromebook 的 LineageOS 23.2 / 24 发布中采用的是 **标准 `.zip` 压缩包（内部封装单个带完整 GPT 分区表的 `.img` 裸盘镜像）**。

这一方案对 Google Gru (`rk3399-gru-scarlet`) **完全适用且是最优解**，原因如下：
1. **Depthcharge 启动机制要求完整 GPT 磁盘**：
   Chromebook 在开发者模式下按 `Ctrl + U` 从外置存储（microSD / USB）启动时，固件（Depthcharge）会扫描外置盘的 GPT 分区表，寻找类型为 `ChromeOS kernel`（GUID `FE3A2A5D-4F32-41A7-B725-ACCC3285A309`）且具备有效启动属性（`priority=15 tries=15 successful=1`）的分区，校验其 `vbutil_kernel` 签名头后加载 FIT 镜像。因此，传统的 Android `fastboot` 线刷包或 Recovery 卡刷包无法直接启动，必须分发完整磁盘镜像（`.img`）。
2. **为什么用 `.zip` 而不是 `.img.xz`？**
   - **BalenaEtcher 的 4 GiB XZ 溢出 Bug**：正如 Trogdor 的 `pack_release_image.sh` 源码注释中所记录，BalenaEtcher 内置的 Node.js `lzma-native` 流式解压器在处理解压后体积超过 4 GiB 的 `.img.xz` 文件时存在 32 位整数溢出 Bug，会在刷写到末尾校验阶段报错 `"Something went wrong. If it is compressed, please check that it is not corrupted."`。
   - **`.zip` 格式全平台通吃**：将 `.img` 封装为标准 `.zip` 后：
     - **BalenaEtcher（Windows / macOS / Linux）**：可直接选择 `.zip` 文件一键刷入 SD 卡，无需手动解压，也不会触发 4 GiB XZ Bug。
     - **Rufus（Windows）**：原生支持直接选择 `.zip` 或解压后的 `.img` 以 DD 模式写入 SD 卡（你之前在 Windows 上用 Rufus 刷写 Trogdor 镜像的体验可以直接无缝复用到 Gru 上）。
     - **Linux / macOS 命令行**：`unzip -p lineage-23.2-gru-YYYYMMDD.zip | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync`。
3. **高压缩比**：
   虽然基础裸盘镜像设定为约 `10.5 GiB`（可直接写入任何 16 GB、32 GB、64 GB、128 GB+ 的 SD 卡），但其中 `super` 未占满部分与刚格式化的 `userdata` 均为全零块，使用 `7z a -tzip -mx=1 -mmt=on` 或 `zip` 压缩后，最终 `.zip` 分发包体积仅约 **1.0 ~ 1.2 GiB**。

---

## 4. Gru 专属打包架构与相对于 Trogdor 的 5 项关键适配

虽然我们可以借鉴 Trogdor 的 `pack_kpart.sh` + `pack_release_image.sh` + `expand_userdata.sh` 三段式流水线，但 Gru (`rk3399-gru-scarlet`) 与 Trogdor (`sc7180`) 在引导、看门狗和挂载阶段存在 5 处本质差异，必须在我们的打包方案中专门适配：

### 4.1 差异一：宿主机端全自动生成 `kernel.kpart`（告别上机 `depthchargectl`）

在阶段 1～4 中，我们每次修改 ramdisk 或内核都需要将文件上传到机器的 postmarketOS 中运行 `depthchargectl build`。在阶段 5 中，我们改为在 **x86_64 宿主机** 上直接利用 LineageOS 源码树自带的二进制工具链合成 `kernel.kpart`：
- **工具链来源（全部来自 LineageOS 树，无需额外安装系统包）**：
  - `lzma` / `xz`：宿主系统自带，用于将内核 `Image` 压缩为 `Image.lzma`（Gru 的 Depthcharge 已验证支持 `lzma` 压缩的 `kernel_noload` FIT 节点）。
  - `mkimage`：`prebuilts/tools-lineage/linux-x86/bin/mkimage`
  - `dtc`：`prebuilts/kernel-build-tools/linux-x86/bin/dtc`
  - `futility`（含 `vbutil_kernel`）：由 `external/vboot_reference` 编译出的 `out/host/linux-x86/bin/futility-host`
  - 签名开发密钥：`external/vboot_reference/tests/devkeys/kernel.keyblock` 与 `kernel_data_key.vbprivk`
- **多板型通用 FIT 设备树（Universal Gru FIT）**：
  将 `linux-6.6.34` 编译出的全部 5 块 Gru 系列 DTB 一并打入 `kernel.its`，由 Depthcharge 固件按硬件板号自动匹配，默认配置指向已实机验证的 `rk3399-gru-scarlet-kd.dtb`：
  1. `rk3399-gru-scarlet-kd.dtb`（Acer Chromebook Tab 10 / Kingdisplay 面板，**已完整实机验证，设为默认 `default`**）
  2. `rk3399-gru-scarlet-inx.dtb`（Acer Chromebook Tab 10 / Innolux 面板变体）
  3. `rk3399-gru-scarlet-dumo.dtb`（ASUS Chromebook Tablet CT100）
  4. `rk3399-gru-kevin.dtb`（Samsung Chromebook Plus）
  5. `rk3399-gru-bob.dtb`（ASUS Chromebook Flip C101PA）
- **Ramdisk 封装**：自动调用 `wrap-ramdisk.sh` 将 `gru-keep`（看门狗接管与早期日志守护进程）、`watchdog.ko`、`dw_wdt.ko` 及 `prebuilt/6.6.34-phase2/*.ko` 注入 `ramdisk.img`。

### 4.2 差异二：GPT 分区表几何布局（10.5 GiB 紧凑基础镜像）

为了兼容市面上所有标注 16 GB（实际可用约 14.4 ~ 14.8 GiB）及更大容量的 microSD 卡，并缩短 Rufus / BalenaEtcher 的刷写时间，我们将基础裸盘镜像大小设定为 **10.5 GiB（22,020,096 个 512 字节扇区）**，所有分区均按 **4 MiB（8192 扇区）对齐**：

| 分区号 | 分区名 (`PARTLABEL`) | 起始扇区 | 扇区数 | 容量 | 类型 / 文件系统 | 用途说明 |
| :---: | :--- | :---: | :---: | :---: | :--- | :--- |
| `p1` | `KERN-A` | `8192` | `131072` | `64 MiB` | ChromeOS kernel (`priority=15 tries=15 successful=1`) | Depthcharge 启动分区（存放 `kernel.kpart`） |
| `p2` | `bootlog` | `139264` | `32768` | `16 MiB` | `ext4` (`label=bootlog`) | 供 `gru-keep` 记录早期启动与内核日志 `/bootlog/gru-phase3.log` |
| `p3` | `metadata` | `172032` | `32768` | `16 MiB` | `ext4` (`label=metadata`) | Android FBE 元数据加密密钥存储 |
| `p4` | `misc` | `204800` | `16384` | `8 MiB` | `raw` | Android BCB（Bootloader Control Block） |
| `p5` | `super` | `221184` | `16777216` | `8192 MiB` (8 GiB) | `raw` (unsparsed `super.img`) | Android 动态逻辑分区容器（`system`/`vendor`/`product`/`system_ext`/`dlkm`） |
| `p6` | `userdata` | `16998400` | `5021662` | `~2.39 GiB` (初始) | `f2fs` (`label=data`) | Android `/data` 用户数据分区，**首次启动时自动无损扩容至整张 SD 卡末尾** |

> **注**：宿主机打包脚本可直接使用 LineageOS 编译出的宿主机工具 `sgdisk`（或 `cgpt`）创建上述 GPT 表并设置 `KERN-A` 的 ChromeOS kernel GUID 与属性位（Attribute bits 48..63），无需依赖宿主机额外安装 `cgpt`。

### 4.3 差异三：首次开机自动扩容 `userdata`（`expand_userdata.sh` 与 `first_stage_mount` 冲突解决）

在分析 Trogdor 的 `scripts/expand_userdata.sh` 时，我们发现了一个**如果直接照搬到 Gru 上会导致扩容失败的关键细节**：
- Trogdor 的 `expand_userdata.sh` 在 `on post-fs` 阶段运行，并假设此时 `/data` 尚未挂载（Trogdor 在 `late-fs` 才挂载 `userdata`），因此它在更新 GPT 分区表与调用 `blkpg_resize` 通知内核更新分区大小后，直接执行离线扩容命令 `resize.f2fs /dev/block/mmcblk0pX`。
- **但在 Gru 上**：我们的 `fstab.gru` 为 `/data` 配置了 `first_stage_mount`（因为早期的阶段 3 调试发现 `latemount` 会导致 `/data` 状态异常），且 `init.gru.rc` 在 `on fs` 阶段就执行了 `mount_all`。这意味着到了 `on post-fs` 阶段，**`/data` 已经处于挂载（mounted）状态**！此时直接运行 `resize.f2fs` 会因设备已挂载（`Device is mounted`）而拒绝执行。

**Gru 的解决方案（双保险设计）**：
1. **分区分辨与安全锁**：脚本只操作 `fe320000.mmc`（外置 microSD 卡控制器）下的 `userdata` 分区（`/dev/block/by-name/userdata` 指向的 `/dev/block/mmcblkXp6`），并通过检查 `/sys/class/block/mmcblkX` 的控制器物理路径严格拒绝任何针对 `fe330000.sdhci`（内置 eMMC）的操作。
2. **安全卸载与 GPT 扩容、内核在线通知**：
   - 当检测到 `userdata` 当前扇区数小于磁盘剩余可用扇区数（差值 > 16 MiB）时，首先检查 `/data` 是否已在 `first_stage_mount` 中挂载；若已挂载（此时处于 `on post-fs` 极早期，`vold` 尚未加密初始化且 `early_hal` / `post-fs-data` 尚未触发，无进程占用 `/data`），先执行 `umount /data` 临时卸载。
   - 随后依次执行：
     1. `/system/bin/sgdisk --move-second-header /dev/block/mmcblkX`（将备份 GPT 表移至物理 SD 卡最末端）
     2. 读取原分区 `PARTUUID` 并执行 `/system/bin/sgdisk --delete=6 --new=6:${START}:0 --partition-guid=6:${PARTUUID} --change-name=6:userdata /dev/block/mmcblkX`
     3. 调用 `/vendor/bin/blkpg_resize`（通过 `BLKPG_RESIZE_PARTITION` ioctl）实时更新 Linux 内核中的 `mmcblkXp6` 分区大小，无需重启。
3. **F2FS 离线无损扩容与重新挂载**：
   - 注意：Linux 6.6 内核中的 `F2FS_IOC_RESIZE_FS` ioctl 仅支持缩容（`if (block_count > old_block_count) return -EINVAL;`），F2FS 扩容必须通过用户态 `/system/bin/resize.f2fs` 在未挂载状态下完成。
   - 因此在 `blkpg_resize` 更新内核分区大小后，脚本直接调用 `/system/bin/resize.f2fs` 将 F2FS 扩展至整卡末端，最后按原挂载参数重新 `mount -t f2fs` 挂载 `/data`，后续 `post-fs-data` 与 FBE 加密流程完全无感衔接，首次开机即可 100% 完成无损扩容且无需二次重启。

### 4.4 差异四：硬件隔离保障（100% 保护内置 eMMC 上的 postmarketOS）

用户将镜像写入 microSD 卡并按 `Ctrl + U` 启动时，如何确保内置 eMMC 上的 postmarketOS 绝对安全？
1. **内核命令行硬绑定外置 MMC 控制器**：
   `cmdline.txt` 中明确指定 `androidboot.boot_devices=fe320000.mmc`。在 RK3399 上，`fe320000.mmc` 固定对应外置 microSD 卡槽，而内置 eMMC 固定挂载在 `fe330000.sdhci`。
2. **Android Init 符号链接隔离**：
   Android 第一阶段 `init` 只会为 `androidboot.boot_devices`（即 `fe320000.mmc`）下的 GPT 分区创建 `/dev/block/by-name/{super,metadata,userdata,misc}` 符号链接。即便内置 eMMC 上存在同名分区，Android 也永远不会挂载或格式化内置 eMMC。
3. **不包含任何写 eMMC 的脚本**：
   与 Trogdor 附带 `install_to_emmc.sh` 不同，我们的镜像面向纯 SD 卡启动设计，系统中不打包任何写入内置存储的脚本或应用。拔下 microSD 卡重启即可回到内置 eMMC 上的 postmarketOS。

### 4.5 差异五：开机向导与开箱即用体验

- LineageOS 23.2 默认包含 `SetupWizard`，在未刷入 GApps 的纯 LineageOS 构建中可正常点击完成初始化向导；同时 `init.gru.rc` 已配置自动启用蓝牙、设置默认屏幕超时、开启桌面模式开发选项并校准音频路由，用户刷卡开机即可直接使用 Wi-Fi、蓝牙、相机、麦克风录音、扬声器/耳机音频与硬件解码视频播放。

---

## 5. 阶段 5 实施步骤清单（Action Plan）

我们将按以下 4 个步骤落地阶段 5：

1. **步骤 1：仓库解耦与预编译产物入库（修复 `.gitignore` 与清理硬编码）**
   - 修改 `device/google/gru/.gitignore`，取消对 `modules.mk` 与 `prebuilt/` 的忽略。
   - 将构建 `super.img` 和 `kernel.kpart` 所需的预编译文件（`modules.mk`、`prebuilt/6.6.34-phase2/`、`prebuilt/gru-keep`、`prebuilt/watchdog.ko`、`prebuilt/dw_wdt.ko`，以及 `prebuilt/6.6.34-phase2/Image` 与 5 个 `rk3399-gru-*.dtb`）整理入库。
   - 优化 `gru-keep.c`（当 `super` 已出现且 `bootlog` 不存在时不阻塞 45 秒）并重新编译静态二进制 `prebuilt/gru-keep`。
   - 添加根目录 `LICENSE` 文件。

2. **步骤 2：集成在线自动扩容组件（`blkpg_resize` + `expand_userdata.sh`）**
   - 在 `device/google/gru/tools/blkpg_resize/` 下添加 `blkpg_resize.c`（支持 `BLKPG_RESIZE_PARTITION` 与 `F2FS_IOC_RESIZE_FS` 在线扩容）并在 `device.mk` 中加入 `PRODUCT_PACKAGES += blkpg_resize`。
   - 编写 `device/google/gru/scripts/expand_userdata.sh`，并在 `init.gru.rc` 的 `on post-fs` 阶段通过 `exec_start expand_userdata` 触发。

3. **步骤 3：编写宿主机一键打包脚本（`pack_kpart.sh` 与 `pack_release_image.sh`）**
   - `device/google/gru/tools/pack_kpart.sh`：在宿主机调用 `wrap-ramdisk.sh`、`lzma`、`mkimage`、`futility-host` 生成包含全部 5 款 Gru DTB（默认 `rk3399-gru-scarlet-kd`）的 `vmlinuz.kpart`。
   - `device/google/gru/tools/pack_release_image.sh`：将 `vmlinuz.kpart`、`super.img`（自动通过 `simg2img` 展开）、格式化好的 `bootlog.img`（`ext4`）、`metadata.img`（`ext4`）与 `userdata.img`（`f2fs`）组装为带 ChromeOS GPT 分区表的 `lineage-23.2-gru-YYYYMMDD.img`，默认打包为兼容 BalenaEtcher / Rufus 的 `lineage-23.2-gru-YYYYMMDD.zip` 并输出 `.sha256` 校验和文件。

4. **步骤 4：更新 `README.md` 用户安装指南与实机刷卡验证**
   - 在 `README.md` 中补充面向终端用户的完整刷机说明（开启开发者模式、`crossystem dev_boot_usb=1`、使用 Rufus / BalenaEtcher 刷入 `.zip`、`Ctrl + U` 启动、校验和核对）以及面向开发者的从源码构建发布包说明。
   - 生成首个正式分发包 `lineage-23.2-gru-YYYYMMDD.zip`，由你用 Rufus 或 BalenaEtcher 写入 SD 卡进行最终实机启动与自动扩容验证。

---

## 6. 推进记录

| 日期 | 阶段 | 完成内容 |
| :--- | :--- | :--- |
| 2026-10-21 | **步骤 1（已完成）** | 1. **解除 `.gitignore` 屏蔽并纳入预编译产物**：更新 `device/google/gru/.gitignore`，将 `device/google/gru/modules.mk`、`prebuilt/gru-keep`、`prebuilt/watchdog.ko`、`prebuilt/dw_wdt.ko`、`prebuilt/6.6.34-phase2/*.ko`（87 个早期 ramdisk 模块）纳入版本控制；同步拷入 `6.6.34-phase2` 内核 `Image` 与全部 5 个 Gru 系列 DTB（`rk3399-gru-scarlet-kd.dtb` [已校验为 `dr_mode = "host"` 正式版]、`scarlet-inx`、`scarlet-dumo`、`kevin`、`bob`）。<br>2. **优化 `gru-keep.c` 并重编静态二进制**：在等待 `bootlog` 分区的循环中增加 `find_part("super", ...)` 探测，当外置存储控制器已就绪但磁盘不含 `bootlog` 分区时不再阻塞 45 秒；修复 `snprintf` 截断告警并重新静态编译 `prebuilt/gru-keep`。<br>3. **消除硬编码路径与归档调试脚本**：移除 `wrap-ramdisk.sh` 与 `prepare-ramdisk-modules.sh` 中的个人本地路径（改为基于 `$ANDROID_BUILD_TOP` 与参数推导）；将阶段 3 设备端刷写脚本（`write*.sh`、`readlog.sh`、`flash-sparse.py`、`partition-table.txt`）归档至 `device/google/gru/tools/bringup/` 并参数化 `DIR`。<br>4. **开源许可声明**：新增根目录 `LICENSE`（Apache-2.0 主许可证 + Linux GPL-2.0 内核模块/补丁与 `linux-firmware` 固件分发声明）。 |
| 2026-10-21 | **步骤 2（已完成）** | 1. **新增 `/vendor/bin/blkpg_resize`**：在 `device/google/gru/tools/blkpg_resize/` 下创建 `blkpg_resize.c` 与 `Android.bp`，通过 `BLKPG_RESIZE_PARTITION` ioctl 在不重启内核的情况下实时刷新分区表大小。<br>2. **新增 `/vendor/bin/expand_userdata.sh`**：在 `device/google/gru/scripts/expand_userdata.sh` 中实现首次启动自动扩容逻辑（带 `fe320000.mmc` 外置 SD 卡控制器校验锁，绝不触碰 `fe330000.sdhci` 内置 eMMC；针对 `first_stage_mount` 已挂载的 `/data`，在 `on post-fs` 早期临时 `umount /data` -> `sgdisk --move-second-header` 扩展 GPT 分区并保留 `PARTUUID` -> `blkpg_resize` 通知内核 -> `resize.f2fs -f -F` 非交互式离线扩容 -> 按原参数重新挂载 `/data`）。<br>3. **集成至设备树与编译验证**：在 `device.mk` 与 `init.gru.rc` 中注册 `blkpg_resize` 与 `expand_userdata` 服务，并同步编译产出目标机 `vendor/bin/blkpg_resize` 以及阶段 3 打包所需的宿主机工具 `futility-host` 与 `sgdisk`。 |
| 2026-10-21 | **步骤 3（已完成）** | 1. **编写宿主机 Depthcharge FIT 打包脚本 (`device/google/gru/tools/pack_kpart.sh`)**：完全在 x86_64 宿主机上调用 `wrap-ramdisk.sh`、`lzma`、`mkimage`（`prebuilts/tools-lineage`）、`dtc` 与 `futility-host vbutil_kernel`，将 `6.6.34-phase2` 内核 `vmlinuz`、全部 5 款 Gru 设备树（`rk3399-gru-scarlet-kd` 默认，兼顾 `scarlet-inx`/`scarlet-dumo`/`kevin`/`bob`）与包装后的 `ramdisk` 组装并签名为 `vmlinuz.kpart`（大小 `14,426,112` 字节，通过 `futility-host vbutil_kernel --verify` 签名校验）。<br>2. **编写宿主机完整刷机镜像与分发压缩包脚本 (`device/google/gru/tools/pack_release_image.sh`)**：将含 `blkpg_resize` 与 `expand_userdata.sh` 的最新 `super.img`（自动展开为 8 GiB raw）、`vmlinuz.kpart`、`bootlog.img`（16 MiB `ext4`）、`metadata.img`（16 MiB `ext4`）与 `userdata.img`（2450 MiB `f2fs`，开启 `-g android -O encrypt,extra_attr,project_quota,quota,verity,compression` 并通过真机 `6.6.34-phase2` 内核挂载与 `resize.f2fs -f -F` 扩容验证）写入 10.5 GiB GPT 磁盘镜像，通过 `sgdisk` 写入 ChromeOS kernel GUID 与启动属性位（`0x01FF000000000000`，即 `priority=15 tries=15 successful=1`）。<br>3. **产出首个正式发布包**：生成 `out/target/product/gru/lineage-23.2-gru-20261021.img`（10.5 GiB）与兼容 Rufus / BalenaEtcher 的 `lineage-23.2-gru-20261021.zip`（大小 `1,038,588,155` 字节 / `990 MiB`，SHA-256: `f8d8b447b1af5f5fbb5b0531372bb91a9cd129d8a251372fdb1796d2d42ee23d`）。 |
| 2026-10-21 | **步骤 4 回归：Rufus 写入 `.zip` 后无法开机（背光不亮）** | 1. **现象与日志对照**：失败卡的 `gru-phase3.log` 中 `servicemanager` 报 `Could not find mapper/minigbm_upstream in the VINTF manifest`，`surfaceflinger` 在 `GraphicBufferMapper::GraphicBufferMapper()` 中 `Abort message: 'gralloc-mapper is missing'`，4 次崩溃后 `init` 判定 `updatable components 'surfaceflinger' exited 4 times before boot completed` 并杀掉 `zygote`；能开机的卡 `gru-phase3_normal.log` 则是 `Found mapper/minigbm_upstream in device VINTF manifest`。内核、ramdisk、GPT、`super` 动态分区挂载与 `expand_userdata` 在两张卡上都正常，唯一的致命差异是 `vendor` 里缺 mapper。<br>2. **根因（阶段 5 的构建方式，而不是设备树代码）**：阶段 4 所有实机验证过的镜像都由 `breakfast gru` 构建，即 `TARGET_RELEASE=bp4a`（`out/verbose.log.*` 中为 `release_config-lineage_gru-bp4a`）；阶段 5 的 `README.md` 改写为 `lunch lineage_gru-trunk_staging-userdebug`，13:46 的发布构建因此切到 `trunk_staging`。`trunk_staging` 把 `RELEASE_SM_OPEN_DECLARED_PASSTHROUGH_HAL` 设为 `true`（`bp4a` 中为空），`external/minigbm-upstream/apex/Android.bp` 据此让 gralloc APEX 通过 `overrides` 删掉独立的 `/vendor/lib64/hw/mapper.minigbm_upstream.so` 与 `/vendor/etc/vintf/manifest/mapper.minigbm_upstream.xml`，而 `out/` 中的 APEX 仍是 `bp4a` 下构建的旧版本（`image.apex/lib64/hw/` 中没有 mapper），两边都没有 mapper。同时 `system`/`product`/`system_ext` 仍是 11:42 的 `bp4a` 产物，`vendor.img` 却是 13:49 的 `trunk_staging` 产物，形成混合镜像。这与阶段 4 第 365 行记录的「`TARGET_RELEASE` 切换后被 `installclean` 误删 mapper」是同一个问题。<br>3. **修复**：`AndroidProducts.mk` 的 `COMMON_LUNCH_CHOICES` 与 `README.md` 改为 `lineage_gru-bp4a-userdebug` / `breakfast gru`；`pack_release_image.sh` 在打包前用 `fsck.erofs --extract` 检查 `vendor.img` 内必须有 mapper 库与 VINTF 片段，并要求 `super.img` 不早于 `vendor.img`，否则拒绝出包。<br>4. **顺带修复的自动扩容隐患**：失败卡日志显示 `userdata` 分区已扩到 `105168863` 扇区，但 F2FS 仍为 `5017600` 扇区（2450 MB），而 `expand_userdata.sh` 只按分区大小判断「已扩容」直接退出，导致文件系统永远停在 2.39 GiB。现改为同时读取 F2FS 超级块 `block_count`，分区已扩但文件系统未扩时仍会离线执行 `resize.f2fs`，并记录 `sgdisk` / `blkpg_resize` / `resize.f2fs` 的返回值。 |
| 2026-10-21 | **步骤 4 回归 2：能开机、有背光但黑屏无画面** | 1. **现象与日志对照**：`gru-phase3_nopicture.log` 中 SurfaceFlinger 已 `Boot is finished`，插充电器有提示音，但从未执行任何 `sys.boot_completed=1` 动作；`system_server` 每秒向 `servicemanager` 查询一次 `android.hardware.usb.gadget.IUsbGadget/default`（`init` 回应 `Could not find 'aidl/...IUsbGadget/default'`），而能开机的 `gru-phase3_normal.log` 中只有 `usbd` 查询过一次。`/data/system/dropbox` 中有多条 `system_server_watchdog`（`Blocked in handler on display thread (android.display) for 69s`），`/data/anr` 的 trace 显示卡在 `UsbService.<init>`（`UsbService.java:220`）→ `UsbDeviceManager.<init>` → `UsbGadgetAidl.connectToProxy` → `ServiceManager.waitForService`。<br>2. **根因（阶段 5 步骤 1 纳入版本控制的 ramdisk 模块）**：`UsbService` 只在 `/sys/class/android_usb` 存在时才创建 `UsbDeviceManager`。`prebuilt/6.6.34-phase2/libcomposite.ko` 与 `usb_f_fs.ko` 是 10-20 17:27 USB 步骤 3（gadget 实验，见 `docs/usb.md`）编译的版本，其 `gadget_cfs_init()` 在模块加载时 `class_create("android_usb")`。实验回退时只还原了 `device/google/gru/modules/` 与内核源码，被 `.gitignore` 屏蔽的 `prebuilt/6.6.34-phase2/` 仍留着实验模块，步骤 1 将其原样提交并打进 `vmlinuz.kpart`。gadget HAL 按 gru 的 host-only 策略从不启动，`waitForService` 永远阻塞，`system_server` watchdog 反复重启，界面始终不绘制。<br>3. **修复**：用 `modinstall/lib/modules/6.6.34-phase2/kernel/drivers/usb/gadget/` 中的原始模块替换这两个文件（`libcomposite.ko` SHA-256 `c08a2563…`，`usb_f_fs.ko` `71a5c657…`，不含 `android_usb`，188 个导入符号的 modversions CRC 与当前内核 `Module.symvers` 全部一致）；其余 85 个 ramdisk 模块与 `modinstall` 逐字节一致（含已修补的 `cros_ec_keyb.ko`）。`pack_kpart.sh` 新增检查：任一 ramdisk 模块含 `android_usb` 即拒绝打包。<br>4. **重新出包**：`lineage-23.2-gru-20261021.zip`（`1,038,701,555` 字节，SHA-256 `a6d3f428486bf4a0d3d9edcd34a19394600cd41741101b3b068ef6f839f5317e`），`vmlinuz.kpart` SHA-256 `919df74a…`，已确认镜像 `KERN-A` 中不含 `android_usb`。同一张卡上 `userdata` 已由 2.4 GiB 自动扩容至 51 GB，自动扩容在实机上已生效。 |
| 2026-10-21 | **步骤 4（文档已就绪，待实机刷卡验证）** | 1. **全面更新根目录 `README.md`**：补充完整的硬件支持矩阵表、面向终端用户的 microSD 卡刷写指南（开启开发者模式、`crossystem dev_boot_usb=1`、SHA-256 校验、Windows Rufus / BalenaEtcher / Linux `dd` 刷入 `.zip`、`Ctrl + U` 外置盘启动说明与首次启动自动扩容说明），以及面向开发者的从源码构建与一键打包 `pack_release_image.sh` 指南。<br>2. **同步更新 `docs/roadmap.md`**：更新阶段 5 状态与打包产物路径，等待实机刷卡验证。 |

