是，Android 16 里当然也存在你说的这个概念，只是术语通常不是“全屏 raster / 局部 raster”，而是几层机制叠在一起：

- app/HWUI 的 **dirty region / partial update**
- EGL 的 **buffer age**
- SurfaceFlinger 的 **damage region**
- HWC 的 **device composition / overlay**
- 最后 display controller 是否支持有效的 partial update / plane composition

AOSP 的 HWUI 里到现在都还有 `debug.hwui.show_dirty_regions`、`debug.hwui.use_buffer_age`、`debug.hwui.use_partial_updates` 这些开关；其中 `use_partial_updates=false` 会明确强制 surface 每帧 full redraw。[Android Go Source](https://android.googlesource.com/platform/frameworks/base/%2B/a38d32bb09756370c5c28d210a051415e85e0be2/libs/hwui/Properties.h?utm_source=chatgpt.com)

所以你怀疑 Scarlet **“虽然 GPU 加速了，但正在走一种接近每帧全屏重绘/全屏 GPU composition 的路径”**，我认为非常值得查，而且按你描述的现象，我现在甚至会把它放在嫌疑列表很靠前的位置。

### 但这里要区分两个“全屏”

一个 app 自己可能每帧重 raster 整个 2048×1536 surface。

另一个问题是，即使 app 只更新了一部分，SurfaceFlinger 也可能最后把整个显示器的若干 layer 全部重新 GPU composite 到 client framebuffer。

这两个完全可以独立发生。

Android 正常的理想路径更像：

```
app
只重画 dirty region
       ↓
新的部分进入 app buffer
       ↓
SurfaceFlinger 收到 layer
       ↓
HWC 判断：
这个 layer 可以直接给 overlay plane
       ↓
Rockchip VOP 做最终 scanout/composition
```

而一个很糟糕、但依然算“GPU acceleration 正常”的路径可能是：

```
app
2048×1536 大量 redraw
       ↓
SurfaceFlinger
       ↓
HWC: CLIENT
       ↓
RenderEngine / GLES
       ↓
把整个 2048×1536 display 再 composite 一遍
       ↓
VOP 只 scanout 一个最终 framebuffer
```

后者完全可能把 Mali-T860 MP4 榨干。

AOSP 自己也明确说明：HWC 的核心价值之一就是利用 display overlay plane，避免 GPU 把 app、状态栏、导航栏等 layer 重新合成到一个 scratch buffer；如果 layer 落到 client composition，就需要 SurfaceFlinger/GPU 合成。[Android Open Source Project](https://source.android.com/docs/core/graphics/hwc?utm_source=chatgpt.com)

所以：

> **“Panfrost 3D acceleration 正常” ≠ “你的 Android display pipeline 正确”。**

这非常关键。

---

## 你的 35–40fps 这个数字反而很可疑

2048×1536：

**3.15 million pixels/frame**

60Hz 相当于：

**189 MPixel/s，仅仅是每帧扫一次。**

但真实 GPU 工作绝不是一次。

假设一个普通 launcher scrolling frame：

```
app raster             3.15 MP
SurfaceFlinger compose 3.15 MP
wallpaper sampling     3.15 MP
status/nav translucent layers
blur/shadow/alpha
```

很快就可能变成：

**10–20 MP/frame 的实际读写/采样工作量。**

60fps：

> 600–1200 MP/s 级别的像素工作 + 大量内存流量。

对于 Mali-T860 MP4，并不是绝对做不到，但已经进入“任何额外低效都会丢帧”的范围。

如果正常 vendor ChromeOS 当年大量利用 Rockchip VOP planes，而你的 drm_hwcomposer 实现把很多东西退到：

```
CLIENT composition
```

那么从稳定 60 掉成 35–40 是非常合理的。

---

# 你现在第一件应该查的不是 GPU benchmark

而是：

## SurfaceFlinger 到底在怎么 compose

先跑：

```
adb shell dumpsys SurfaceFlinger
```

重点找每个 visible layer 的：

```
Composition type
DEVICE
CLIENT
SOLID_COLOR
CURSOR
```

不同 Android 版本 dump 输出格式会有变化。

你最希望看到普通桌面场景大量是：

```
DEVICE
```

如果看到：

```
CLIENT
CLIENT
CLIENT
CLIENT
```

那我基本会马上怀疑 drm_hwcomposer / plane assignment。

因为 Perfetto 的 Android FrameTimeline 甚至会直接告诉你一帧有没有使用 **GPU Composition**，并且能区分：

- `SurfaceFlingerGpuDeadlineMissed`
- `SurfaceFlingerCpuDeadlineMissed`
- `DisplayHAL`
- app deadline missed

这正是你这个问题的标准诊断方法。[Perfetto](https://perfetto.dev/docs/data-sources/frametimeline?utm_source=chatgpt.com)

---

# 我非常建议你抓一个 Perfetto trace

这个比“肉眼 35fps”有价值得多。

做一个非常简单的 workload：

> Settings 页面快速上下滚动 10 秒。

然后看 FrameTimeline。

如果红帧主要写：

```
SurfaceFlingerGpuDeadlineMissed
```

那几乎就是：

> SF GPU composition 太慢。

如果是：

```
AppDeadlineMissed
```

则更可能是：

> Android HWUI/app raster 慢。

如果是：

```
DisplayHAL
```

则应该去看：

> drm_hwcomposer / DRM atomic commit / fence / VOP。

这三个方向完全不同。Perfetto 官方对这些 jank 分类的定义非常清楚。[Perfetto](https://perfetto.dev/docs/data-sources/frametimeline?utm_source=chatgpt.com)

这一个 trace 很可能就能把你现在的问题空间砍掉 70%。

---

# 第二个实验甚至更简单：显示 dirty region

Android 里还有这个老而好用的调试开关：

```
adb shell setprop debug.hwui.show_dirty_regions true
```

然后重启相关 app，必要时重启 framework/device。

HWUI 会把 dirty region 可视化；AOSP 的属性定义明确就是：

> draw dirty regions every other frame. [Android Go Source](https://android.googlesource.com/platform/frameworks/base/%2B/a38d32bb09756370c5c28d210a051415e85e0be2/libs/hwui/Properties.h?utm_source=chatgpt.com)

你可以直接看：

> 滚动一小块内容的时候，整个 window 是不是实际上一直被判成 dirty。

不过注意一个重要区别：

### scrolling 本来就经常是“大面积 dirty”

如果你上下滚动一个全屏列表：

```
整个 app surface 的绝大多数像素
```

本来每帧就会改变。

所以“列表滚动时全屏 dirty”不一定是 bug。

这和你之前 Flutter Fluxtube 的问题不完全一样。

视频播放器里，如果只有：

```
video SurfaceView
+
一个小 progress bar
```

UI overlay 的大部分区域理应可以不重画。

而列表 scrolling：

> 每个像素的位置都在变。

因此即使 incremental damage 完全正常，3MP 屏幕 scrolling 依然会造成非常高的 fill/bandwidth load。

这是我认为你之前的类比里需要稍微修正的地方。

---

# 真正更重要的是 buffer age 是否正常

AOSP HWUI 会利用：

```
EGL_EXT_buffer_age
```

实现 partial invalidate。

也就是说三缓冲时：

```
buffer A
上一轮内容还在

本轮只需要补：
过去 N 帧发生变化的区域
```

而不是每次：

```
clear entire buffer
draw whole scene
```

AOSP 明确提供：

```
debug.hwui.use_buffer_age
```

控制这条路径，默认开启；同时 `use_partial_updates` 默认也是开启的。[Android Go Source](https://android.googlesource.com/platform/frameworks/base/%2B/a38d32bb09756370c5c28d210a051415e85e0be2/libs/hwui/Properties.h?utm_source=chatgpt.com)

所以你应该检查 Panfrost Android EGL stack 有没有：

```
EGL_EXT_buffer_age
EGL_KHR_partial_update
```

至少 buffer age 很重要。

例如通过你 build 中可用的 EGL info 工具检查扩展。

如果：

```
EGL_EXT_buffer_age
```

缺失，

HWUI 就可能走不同的 preserved-buffer 路径，甚至更糟糕的 full redraw fallback。

---

# 但我现在其实更怀疑 HWC，而不是 HWUI

原因是你提到了一个很关键的共同点：

> Android 35–40fps  
> Phosh 类似  
> Plasma 类似  
> 后期 ChromeOS 好像也类似

四套完全不同的 UI stack 都卡在差不多的区域。

这让我不太相信：

> Android 16 某个 framework regression

是唯一原因。

反而更像底层共同瓶颈：

```
RK3399
↓
Mali T860 / Panfrost
↓
LPDDR bandwidth
↓
2048×1536 framebuffer
↓
display composition
```

尤其 Scarlet 的显示分辨率对于 RK3399 这个级别，本来就很激进。

如果 Phosh/Wayland、Plasma/Wayland、Android 全都在 3.15MP 下大约 35–45fps，那么很可能已经接近：

> **这套开源 graphics path 在 native resolution 下的实际 fill/bandwidth ceiling。**

---

# 那 Google 当初怎么做到的？

这里我觉得你真正问到了核心。

我完全同意：

> Google 不太可能在 2018 年发布一台从第一天就只能 35fps scrolling 的 ChromeOS 平板。

特别是 Scarlet 是 Google/Acer 真正作为 ChromeOS tablet 产品推出的。

因此我认为有三种很现实的可能。

### 1. 早期 ChromeOS 有 Rockchip 专有优化，而今天 mainline 没有

这是最值得怀疑的。

ChromeOS 当年的 RK3399 graphics stack 很可能不是：

```
mainline Panfrost
+
generic Mesa
+
generic drm_hwcomposer
```

而是：

```
Rockchip/Mali proprietary userspace
+
ChromeOS-specific compositor
+
RK3399 VOP plane assignment
+
平台专项优化
```

例如正确利用：

- VOP overlay planes；
- AFBC；
- buffer modifiers；
- zero-copy scanout；
- direct scanout；
- hardware rotation/composition；
- 特定 governor/QoS。

你的 Panfrost 能跑 3D，并不说明这些能力全部恢复了。

---

### 2. Mali proprietary stack 的性能确实可能比早期 Panfrost 高很多

T860 是 Midgard。

Panfrost 对它已经成熟很多年了，但：

> feature completeness ≠ vendor stack 在特定 workload 的效率完全相同。

尤其：

- tiler utilization；
- memory layout；
- AFBC；
- framebuffer compression；
- DVFS；
- cache/coherency；
- modifier negotiation。

如果某个环节导致 framebuffer 用：

```
linear ARGB8888
```

而原厂是：

```
AFBC compressed tiled buffer
```

对于 3MP 屏幕，带宽差距可能非常大。

这值得专门查。

---

### 3. ChromeOS 早期确实也未必全程 60fps

这个也不能排除。

2018 年的低端 Chromebook 并不一定达到今天我们对 Android flagship 的“锁 60”预期。

也可能：

```
launcher / overview 45–60
网页滚动 40–60
复杂页面掉帧
```

用户当时容忍度更高。

所以你记忆里的：

> “Google 不可能 ship 一个不流畅产品”

并不一定意味着：

> 所有 animation 都严格 16.67ms。

但是如果现在稳定只有 35–40，而且肉眼明显卡，那我还是倾向于认为还有性能没有拿回来。

---

# 还有一个特别值得查的东西：GPU frequency

你必须确认：

> Panfrost 在 workload 下真的 boost 到最高频。

不要只看：

```
3D acceleration works
```

要看：

```
cat /sys/class/devfreq/*gpu*/cur_freq
cat /sys/class/devfreq/*gpu*/available_frequencies
cat /sys/class/devfreq/*gpu*/governor
```

具体节点根据 kernel DT/devfreq 注册情况不同。

如果：

```
max = 800 MHz
```

但 scrolling 时一直：

```
200–400 MHz
```

那你找到一个非常大的问题。

RK3399 mainline 的 GPU DVFS / thermal / devfreq 配置如果没对，完全可能造成：

> GPU 能用，但一直像省电模式。

而且这种症状特别像：

```
0.5fps → enable GPU → 40fps
```

于是很容易误以为：

> 40fps 就是硬件极限。

其实可能只是没 boost。

---

# CPU governor 也要查

Android scrolling 不只是 GPU。

一帧里面：

```
UI thread
RenderThread
SurfaceFlinger
HWC
DRM commit
```

都要赶在 16.67ms deadline 内。

如果 A72：

```
1.4 GHz
```

而不是：

```
2.0 GHz+
```

或者调频反应太慢，

也可能稳定 miss 每隔几个 vsync。

Perfetto 一眼就能看出来到底 CPU 还是 GPU。

---

# 你那台 Exynos 7870 的经历也很有参考意义

Exynos 7870 + Android 12：

> 尚且比较流畅。

Android 14：

> 全局开始明显卡顿。

这并不能简单解释成：

> Android 14 raster engine 变差了。

现代 Android SystemUI 确实比 Android 8/12 更复杂：

```
blur
shadows
rounded clipping
dynamic color
more animations
Compose usage
larger surfaces
```

每一代增加一点 GPU/CPU overhead。

对于旗舰机器没感觉。

但是对于：

```
Mali-T830/T860
```

这种原本刚好卡在：

```
~15ms/frame
```

附近的机器，

只增加：

```
+3–5 ms
```

就会从：

```
60 fps
```

跨过 16.67ms cliff。

然后视觉上突然变成：

```
30–45fps
```

Android 官方也明确指出：60Hz 下只要超过 16ms deadline，就会 miss frame，而不是“17ms = 58.8fps”这么线性。[Android Developers](https://developer.android.com/topic/performance/issues/render?utm_source=chatgpt.com)

所以你看到的是一种典型的：

> **performance cliff。**

---

# 我会建议你做一个非常有价值的实验

把 Scarlet 的 logical/native display 临时降下来。

不是为了最终发布，而是诊断。

例如：

```
adb shell wm size 1440x1080
```

保持 4:3。

或者：

```
adb shell wm size 1600x1200
```

再测 scrolling。

原生：

```
2048×1536
= 3.15 MP
```

1600×1200：

```
1.92 MP
```

只有原来的：

**61%。**

1440×1080：

```
1.56 MP
```

只有：

**49%。**

如果结果：

```
2048×1536 → 38fps
1600×1200 → 55fps
1440×1080 → 60fps locked
```

那基本可以宣布：

> **fill rate / memory bandwidth / composition 是主要瓶颈。**

如果：

```
2048×1536 → 38
1440×1080 → 40
```

那就完全不是像素吞吐问题，应该查：

```
CPU
scheduler
vsync
HWC
frame pacing
```

这个实验的诊断价值非常高。

---

# 然后再做第二个实验：强制禁用 HWC

Android 通常可以通过开发者选项：

> Disable HW overlays

强制所有东西走 GPU composition。

你现在记录一个正常状态：

```
38 fps
```

然后开启：

> Disable HW overlays

如果变成：

```
25 fps
```

说明你的 HWC/overlay **实际上工作了，而且贡献很大**。

如果还是：

```
38 fps
```

甚至没有任何差异，

那就很值得怀疑：

> 你本来就几乎没使用 hardware planes。

这会是一个非常醒目的信号。

---

# 反过来也可以看 GPU utilization

如果 scrolling 时：

```
GPU 95–100%
```

而降分辨率后 fps 大涨：

**GPU/fill/bandwidth ceiling。**

如果：

```
GPU 40%
```

但还是 38fps：

那么不是 GPU 算力不足。

去查：

```
fences
SurfaceFlinger
DisplayHAL
CPU
vsync
DRM commit
```

---

## 所以我目前的判断

我不会告诉你：

> “RK3399 就这样，别折腾了。”

因为你提供的历史背景反而说明**还有优化空间的可能性很高**。

但我也不会把它简单归因于：

> “Android 16 有个 Flutter 一样的 full-screen raster bug。”

更可能是几个层次中的一个：

```
① HWUI partial damage / buffer age 不工作
② drm_hwcomposer 没有效利用 VOP planes
③ framebuffer modifiers / AFBC 没用起来
④ Panfrost GPU DVFS 没拉满
⑤ memory/interconnect devfreq/QoS 太低
⑥ SurfaceFlinger client composition 开销
⑦ Android 16 本身的现代 UI 对 T860 已经太重
```

其中我目前最想先查的是：

> **② HWC composition mode + ③ framebuffer/modifier + ④ DVFS**

而不是先改 Android framework。

因为 Android 已经明确具有 dirty region、buffer age 和 partial updates 机制；“Android 16 天生整屏 raster”这个假设本身并不成立。[Android Go Source](https://android.googlesource.com/platform/frameworks/base/%2B/a38d32bb09756370c5c28d210a051415e85e0be2/libs/hwui/Properties.h?utm_source=chatgpt.com)

如果你愿意继续追这个性能问题，**最有价值的下一条消息不是描述体感，而是贴一个 scrolling 时的 Perfetto FrameTimeline + `dumpsys SurfaceFlinger` composition dump**。那样我们基本可以判断到底是 app raster、SurfaceFlinger GPU compose、DisplayHAL，还是纯粹 T860 达到像素吞吐极限。
