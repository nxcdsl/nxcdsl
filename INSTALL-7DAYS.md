# 灵绘 · 7 天自签一页清单

> 打印出来或者截屏放手机里，照着点就行。细节解释在 `README.md`。

## A. 出包（只做一次，5–8 分钟）

- [ ] 把 `LumiGen` 文件夹的内容传到一个 GitHub 仓库（网页拖拽即可，Private 也行）
- [ ] 仓库 → **Actions** → `Build unsigned IPA` → **Run workflow**
- [ ] 跑完 → 页面底部 **Artifacts** → 下载 → 解压出 `LumiGen-unsigned.ipa`

## B. 电脑（只做一次）

- [ ] 卸载微软商店版 iTunes，装 [apple.com 官网版 iTunes](https://www.apple.com/itunes/download/standalone)
- [ ] 装 [Sideloadly](https://sideloadly.io)（0.70 以上）
- [ ] 杀软弹窗全部允许，或把 Sideloadly 加白名单

## C. 装到手机（每次续签都走这一段）

- [ ] 手机设好**锁屏密码**
- [ ] 数据线连电脑（要能传数据的线，别用扩展坞）→ 手机点「信任」→ 输密码
- [ ] Sideloadly 左上角确认显示 iPhone Air
- [ ] 把 `LumiGen-unsigned.ipa` 拖进 Sideloadly 窗口
- [ ] **Apple ID** 填邮箱 → 其他全部默认 → **Start**
- [ ] 依次输入：Apple ID 密码 → 手机弹出双重认证点「允许」→ 把 6 位码填进 Sideloadly
- [ ] 看到 `Done.` → 桌面出现「灵绘」

## D. 手机上（只做一次）

- [ ] 设置 → 通用 → **VPN 与设备管理** → 开发者 App → 你的 Apple ID → **信任**
- [ ] 设置 → 隐私与安全性 → **开发者模式** → 打开 → 重启 → 解锁后点「打开」
      （找不到这一项：先点一下「灵绘」图标，再回来找）

## E. 第一次用

- [ ] 打开「灵绘」→ 点「下载 2.6 GB」→ **Wi-Fi + 别锁屏**
- [ ] 回主界面，写一句话，选风格，点 ✦

## F. 每 7 天续签（到期前做，别等它打不开）

- [ ] 插线 → Sideloadly → **同一个 ipa + 同一个 Apple ID** → Start（不用先删 App）
- [ ] 桌面图标还在、数据一般都在，直接能用

**怕模型重下？** 续签前打开「文件」App → 我的 iPhone → 灵绘 → 把 `Models` 文件夹**拷贝**一份到「我的 iPhone」根目录（或 iCloud 云盘）。万一续签后模型没了，再拷回来放回 `灵绘/Models` 即可，App 会自动认出来。

## G. 免费账号的限制

- 同时最多 **3 个**自签 App；每 7 天最多注册 **10 个** App ID
- 证书到期后 App 会「一点就闪退」，不是坏了，是签名过期

## H. 报错速查

| 看到什么 | 怎么办 |
|---|---|
| 一堆红字 `Guru Meditation` / `anisette` | 装官网 iTunes；关 VPN；杀软放行；重开 Sideloadly |
| `maximum number of apps ... reached` | 免费号已装 3 个，删一个旧的 |
| 图标白 / 点开闪退 | 没信任证书 → 回 D 第一步 |
| `Unable to install ... Please verify` | 开发者模式没开 → D 第二步；或换线、换 USB 口 |
| 卡在 `Signing...` | 关掉 iTunes 和 Sideloadly 重来 |

## I. 想彻底不折腾

- 99 美元开发者账号：签名 1 年有效，装一次管一年
- AltStore / SideStore：自动续签，但电脑要常开或要配配对文件
