# ChatGPT Lite for iOS 15

一个基于 `ChatGPTwebV15 v1.0.0` 审计后重建的精简 WKWebView 工程。目标是 iOS 15.3+，仅加载官方 `https://chatgpt.com/`，不使用 OpenAI API，也不接入第三方服务。

## 本版范围

- iOS 15.3+，iPhone 与 iPad
- 使用官方 `chatgpt.com` 网页和官方账号
- 使用持久 `WKWebsiteDataStore.default()` 保存 Cookie 与网站数据
- 登录成功后由官方网页同步账号历史记录
- HTML 文件选择器支持从照片或“文件”中上传图片/文件
- 通过 `WKDownload` 接收普通网页附件，并交给系统“文件”选择器保存
- 处理登录弹窗、新窗口、网页崩溃自动恢复、加载错误与重试
- 仅追加与 iOS 15 WebKit 相符的 Safari UA 产品标记；不伪装 Safari 17

本版没有 Cookie/Session Token 导入、多账号、悬浮按钮、设置页、Obsidian、Apple Watch、语音或 API 功能。

## 安全与兼容边界

- App 不读取、导出或单独保存会话令牌；登录 Cookie 只由 WebKit 保存在应用沙盒中。
- 没有开启任意明文网络访问，所有主页面流量使用 HTTPS。
- `chatgpt.com` 是持续更新的网页，OpenAI 没有承诺 iOS 15 的嵌入式 WebKit 始终受支持。服务端验证或新 JavaScript 语法仍可能让旧系统无法登录或加载。
- Google 等身份提供方可能拒绝嵌入式浏览器登录。这属于提供方策略，不能通过安全的客户端改动保证绕过。请优先使用账号原本的登录方式；不要从桌面浏览器复制会话 Cookie。
- 文件上传由 iOS/WKWebView 的原生 `<input type="file">` 流程处理。下载支持 HTTP 附件和 WebKit 可识别的下载；网站内部使用的特殊 `blob:` 流程可能受旧 WebKit 限制。

## 在 Xcode 中构建

要求：macOS、Xcode 13 或更高版本，以及一个可用于设备安装的 Apple 开发签名。

1. 打开 `ChatGPTLite.xcodeproj`。
2. 选择 `ChatGPTLite` target → **Signing & Capabilities**。
3. 选择自己的 Team，并把 Bundle Identifier 从 `com.example.ChatGPTLite` 改成唯一值。
4. 选择 iOS 15.3+ 真机或模拟器，运行。
5. 真机首次打开后，在 App 内通过官方网页登录。正常关闭或杀掉 App 不会主动清 Cookie。

若使用 SideStore、AltStore 或类似重签工具，可在 Mac 终端执行：

```bash
cd ChatGPTLite-iOS15
chmod +x Scripts/build-unsigned-ipa.sh
./Scripts/build-unsigned-ipa.sh
```

产物位于 `build/ChatGPTLite-unsigned.ipa`，它必须先由你的安装工具重签，不能直接安装。

## 只有 Windows：使用 GitHub 云端构建

工程已经包含 `.github/workflows/build-ipa.yml`。不需要 Mac，可以借用 GitHub 的 macOS 构建机生成未签名 IPA：

1. 在 Windows 解压整个工程。
2. 用 GitHub Desktop 把 `ChatGPTLite-iOS15` 文件夹发布为一个 GitHub 仓库；私有仓库也可以。
3. 在仓库网页打开 **Actions**。
4. 左侧选择 **Build unsigned IPA**，点击 **Run workflow**。
5. 等待绿色完成标记，打开这次运行。
6. 在页面底部 **Artifacts** 下载 `ChatGPTLite-unsigned-IPA`。
7. 解压下载的 ZIP，即可得到 `ChatGPTLite-unsigned.ipa`。

这个 IPA 没有 Apple 签名，必须再通过 SideStore、AltStore、TrollStore 或其他你信任的签名方式安装。GitHub 私有仓库的 macOS Actions 会消耗账号的 Actions 分钟额度。

## 工程文件

- `ChatGPTLite/AppDelegate.swift`：最小 UIKit 启动入口
- `ChatGPTLite/ViewController.swift`：持久 WebView、导航、上传兼容与下载保存
- `ChatGPTLite/Info.plist`：iOS 15.3+ 权限和方向配置
- `ChatGPTLite.xcodeproj`：Xcode 13 兼容格式的单 target 工程
- `Scripts/build-unsigned-ipa.sh`：无签名 IPA 打包脚本
- `.github/workflows/build-ipa.yml`：Windows 用户可点击运行的 GitHub 云端构建
- `SOURCE_AUDIT.md`：上游标签源码与 Release IPA 的核对结果

## 验收建议

请至少在 iOS 15.3/15.3.1 真机验证：

1. 首次打开显示 `chatgpt.com`。
2. 用账号原本的认证方式登录并打开一条电脑端已有对话。
3. 杀掉 App 后重开，确认仍处于登录状态。
4. 新建对话，上传一张照片和一个普通文件。
5. 下载一个 PDF/Word/Excel 附件，确认系统“存储到文件”界面出现。
6. 点击对话里的外部链接，确认交给 Safari；登录重定向仍留在 App 内。

## 来源说明

本工程依据上游 v1.0.0 的公开工程结构和资源进行审计后重建。上游仓库未提供许可证文件；如需公开发布或分发其图标资源，请先向原作者确认授权。
