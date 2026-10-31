# 灵绘 LumiGen

一个**完全离线**的 iPhone AI 出图 App：输入一句中文 / 英文描述，选一个固定风格（二次元、写实、国风…），点一下就有图。
模型跑在手机本地，不联网、不上传、没有内容审查。

界面用 iOS 26 的液态玻璃（Liquid Glass）API 做的：所有面板、胶囊、滑动的风格条都是系统玻璃材质，背景可以换成内置渐变或者你自己的照片。

> **只想照着点？** 直接看一页清单：[`INSTALL-7DAYS.md`](INSTALL-7DAYS.md)（安装 / 续签 / 报错速查都在里面）。

---

## 一、现在需要你做的（15 分钟）

这台电脑是 Windows，装不了 Xcode，所以我准备了**不需要 Mac**的路子：让 GitHub 的云端 Mac 帮你编译出一个 IPA，再用 Windows 上的工具签个名装进手机。

### 第 1 步：上传到 GitHub，自动编译

**最省事的方式**：双击 `Scripts\push-to-github.bat`，粘贴你的空仓库地址（`.git` 结尾），它会自动提交并推送。
先在 GitHub 网页上新建一个**空**仓库（Private 也行），不要勾选 README / .gitignore。

**或者手动来**（不想用脚本）：

1. 在 GitHub 新建一个空仓库，名字随便，比如 `lumigen`。
2. 把 `C:\Users\15035\Projects\LumiGen` 这个文件夹里的**全部内容**上传上去（网页拖拽上传就可以，注意 `.github` 这个隐藏文件夹也要带上）。
3. 打开仓库的 **Actions** 标签 → 左边选 `Build unsigned IPA` → 右边 **Run workflow**。
4. 等 5～8 分钟，跑完后在这一次运行的页面底部 **Artifacts** 里下载 `LumiGen-unsigned-ipa`，解压得到 `LumiGen-unsigned.ipa`。

> 免费额度对个人项目完全够用，一个月编译几次不花钱。
> 如果 `github.com` 打不开，是网络问题（我这边调试环境也被拦了），换个网络或挂个代理再传。

### 第 2 步：用 Sideloadly 签名安装（Windows 上就能做）

1. 电脑装 [iTunes 官网版](https://www.apple.com/itunes/download/standalone)（**别用微软商店版**，缺驱动，会报 Guru Meditation）和 [Sideloadly](https://sideloadly.io)。
2. iPhone 用数据线连电脑（要能传数据的线），手机上点「信任」并输入锁屏密码。
3. 打开 Sideloadly：把 `LumiGen-unsigned.ipa` 拖进窗口 → **Apple ID** 填你自己的 Apple ID → 点 Start → 输入 Apple ID 密码（可能还要在手机上输入双重验证码）。
4. 装完手机上会有个「灵绘」图标。

### 第 3 步：信任自签证书

iPhone 设置 → 通用 → VPN 与设备管理 → 开发者 App → 选你的 Apple ID → 信任。

首次打开如果提示「App 需要开发者模式」：设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启手机。

> **签名有效期**：用免费 Apple ID 签的 App，**7 天**后会打不开。再插上电脑用 Sideloadly 点一次 Start 就续上了，模型不用重新下载（App 里的下载器支持断点续传，同名文件会跳过）。
> 剩余天数在 App 的「外观 → 关于」里能看到，剩 2 天会变黄提醒你。
> 有 99 美元的开发者账号就是 1 年有效，也可以在买号后用 AltStore / SideStore 自动续签。

---

## 二、如果你的朋友 / 你自己有一台 Mac（更省事）

1. 用 Xcode 打开 `LumiGen.xcodeproj`。
2. 选中工程 → Target `LumiGen` → **Signing & Capabilities**：
   - Team 选你的 Apple ID（没有就 Add an Account）；
   - **Bundle Identifier 改成全世界唯一**，比如 `com.你的名字.lumigen`。
3. 手机连上，顶部选你的 iPhone，按 ⌘R，等编译完手机上就有 App 了。

第一次跑完，Xcode 会顺手把设备注册好，之后在「设备管理」里信任一下证书即可。

---

## 三、打开 App 之后（只有三步）

1. 首次打开会自动弹出模型页，点 **下载 2.6 GB**（**一定要连 Wi-Fi**，5～15 分钟，看网速）。
   默认走国内镜像 `hf-mirror.com`，下载不动就在「下载源」里改成 `huggingface.co` 或别的镜像。
   > 下载和出图那几分钟**别锁屏、别切走**，iOS 会掐掉后台任务。
2. 回到主界面，在输入框写一句话，例如：
   - `雨后的老街，一只橘猫蹲在路灯下`
   - `穿白裙子的女孩站在海边，风吹起头发`
3. 滑一下风格条选「二次元 / 写实 / 国风…」，点右边的 **✦**，等 3～10 秒。

出图后左下角三个小按钮：**保存**（进相册）、**分享**、**当背景**（把这张图设成 App 背景）。
想要同一构图的不同版本，再点一次 ✦ 就行（种子会自动 +1）。

右上角的圆形按钮 = 换背景、改出图尺寸、换模型。
顶部「模型名」那个胶囊 = 模型管理。

---

## 四、关于模型（我替你挑的）

**默认：DreamShaper XL Turbo**（Core ML / SDXL 蒸馏版）

| | |
|---|---|
| 体积 | 2.59 GB（装完就躺在本机，不再联网） |
| 步数 | 4 步（蒸馏模型，4 步就出图） |
| 尺寸 | 512 / 768 / 1024 可选，默认 768 |
| 风格 | 二次元、插画、写实、3D 都能打，属于「一个顶一堆」的全能型 |
| 审查 | 没有。模型文件里根本没带 SafetyChecker，代码里也显式关掉了 |

选它的理由很直接：SDXL 的底子 + Turbo 的步数，画质和速度都够用，A19 Pro 上 768px / 4 步大概 4～8 秒，功耗比跑 25 步的普通模型低一个数量级——正好对上你要的「快、省电、质量够」。

**备选：SD 1.5 轻量版**（0.9 GB，22 步，512px）。手机发烫或者只想快速试感觉的时候换它。

**想换成别的模型**（比如某个专门画二次元的 checkpoint）：
在有 Mac 的情况下跑 `Scripts/convert_model.sh`，或者参考 `Scripts/convert_model.sh` 里的命令自己转一个 Core ML 版本，然后把整个文件夹（要有 `Unet.mlmodelc`、`TextEncoder.mlmodelc`、`VAEDecoder.mlmodelc`、`vocab.json`、`merges.txt`）放进 **「文件」App → 我的 iPhone → 灵绘 → Models** 里，App 会自动认出来。

---

## 五、我担心的两个地方（先跟你说清楚）

1. **这台机器是 Windows，我没法编译验证**。代码是照苹果官方 `ml-stable-diffusion` 的接口写的（源码我已经整份放进 `LumiGen/SDEngine/`，不依赖网络拉包），逻辑上没问题，但第一次编译如果报错，把红字发我，基本都是改一两行的事。
2. **液态玻璃**：`LumiGen/UI/GlassKit.swift` 里用一个开关控制。Xcode 26 编译时用真正的 `glassEffect`；如果你用的是老版本 Xcode（没有 iOS 26 SDK），它会自动退回一层视觉上很像的拟态玻璃，照样能跑。万一 `glassEffect` 报错，把文件里的 `useSystemGlass` 改成 `false` 就好。

---

## 六、目录结构

```
LumiGen/
├─ LumiGen.xcodeproj          Xcode 工程（已含共享 scheme，CI 能直接用）
├─ Config/Info.plist          权限、文件共享、深色模式
├─ LumiGen/
│  ├─ LumiGenApp.swift        入口 + 根视图
│  ├─ Core/
│  │  ├─ Models.swift         模型预设、风格预设、尺寸
│  │  ├─ ModelLibrary.swift   已装模型的扫描与选择
│  │  ├─ ModelInstaller.swift 从镜像站下载模型（断点续传）+ 进度
│  │  ├─ GeneratorEngine.swift 包住苹果管线的推理引擎
│  │  ├─ Studio.swift         全局状态 / 出图流程
│  │  ├─ Provisioning.swift   读证书到期时间（7 天签名提醒）
│  │  └─ ImageExport.swift    存相册、分享面板
│  ├─ UI/
│  │  ├─ GlassKit.swift       液态玻璃 + 退回方案
│  │  ├─ Theme.swift          6 套渐变背景 + 自定义照片
│  │  ├─ HomeView.swift       顶栏
│  │  ├─ ResultCanvas.swift   画布 / 进度 / 结果操作
│  │  ├─ PromptDock.swift     风格条 + 输入框 + 生成键
│  │  ├─ ModelSetupView.swift 模型下载与管理
│  │  └─ SettingsView.swift   外观 / 尺寸 / 关于（含签名剩余天数）
│  ├─ SDEngine/               苹果 ml-stable-diffusion 的 Swift 管线（MIT，已内置）
│  └─ Resources/Assets.xcassets  App 图标（深色玻璃星芒）
├─ Scripts/
│  ├─ push-to-github.bat      双击 → 粘仓库地址 → 自动推送到 GitHub
│  └─ convert_model.sh        （可选）在 Mac 上转换任意模型
├─ INSTALL-7DAYS.md           一页清单：装 / 信任 / 续签 / 报错速查
└─ .github/workflows/build-ipa.yml  云端编译出未签名 IPA
```

---

## 七、隐私

- 出图全程在手机本地，不联网、不上传。
- 联网只有两处：下载模型；你主动点「从相册选背景」（只是读你选的那张图）。
- 生成的图除了你手动点「保存」进相册，不会离开 App 的沙盒。

## 八、许可

内置的 `LumiGen/SDEngine/` 来自 Apple `ml-stable-diffusion`，MIT 许可（见同目录 `LICENSE-apple-ml-stable-diffusion.md`）。
模型权重是各自作者发布的开源模型，商业使用请自行确认对应模型页的许可。
