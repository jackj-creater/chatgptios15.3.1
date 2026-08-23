# v1.0.0 源码与 Release 核对

核对日期：2026-08-23

## 上游对象

- 仓库：`Akuma1tko/ChatGPTwebV15`
- 标签：`v1.0.0`
- 标签提交：`0d0bd22b8ce6fff44b8871891f49aae58bc4271b`
- Release 资产：`ChatGPTw15.ipa`
- Release 资产 SHA-256：`31f5c2f864c758e96e6b49853f22fc98d2af6b3dc9f859101d0552a8212e4eb0`
- Release 资产创建时间：2025-08-27T19:40:37Z

## 结论

Release IPA 不是由 v1.0.0 标签中可见源码直接构建出的同一工程版本。

证据：

1. 标签源码的 `AppDelegate.swift` 引用 `CookieEntryView()`，但仓库没有这个类型的源码，因此标签内容按原样无法编译。
2. 标签源码只包含 `AppDelegate.swift` 和 `ViewController.swift` 两个 Swift 文件；Release 可执行文件中存在 `TokenLoginViewController`、`WebViewController`、`AccountManagerViewController`、`FloatingButton` 和 Keychain 相关符号。
3. 标签源码加载 `https://chat.openai.com`，并向 `chat.openai.com` 注入 Cookie；Release 可执行文件包含 `https://chatgpt.com` 和 `chatgpt.com` Cookie 域。
4. 标签源码把 `sessionCookie` 放在 `UserDefaults`；Release 的符号和内嵌 provisioning 信息显示它还有未提交的账号/Keychain 实现。
5. Release 页面在 2025-07-13 发布，但当前 IPA 资产在 2025-08-27 创建/上传，晚约 45 天。

## Release IPA 元数据

- `CFBundleIdentifier`: `com.akuma.chatgptv15`
- `CFBundleShortVersionString`: `1.0`
- `MinimumOSVersion`: `15.1`
- 构建工具：Xcode 16.4 (`DTXcode` 1640)
- SDK：iPhoneOS 18.5
- 支持设备：iPhone、iPad

## 标签源码中发现的问题

- 缺失 `CookieEntryView`，导致编译失败。
- 仍使用旧入口 `chat.openai.com`。
- Cookie 注入域与当前 `chatgpt.com` 不一致。
- 手动复制 `__Secure-next-auth.session-token` 会扩大账号会话泄露风险。
- `Info.plist` 开启 `NSAllowsArbitraryLoads`，但本应用不需要明文网络访问。
- iOS target 绑定原作者 Team 与 Bundle ID，并混入 macOS/xrOS 设置。
- iOS entitlement 文件包含 macOS App Sandbox entitlement，不适合这个 iOS-only target。
- 工程 target 声称最低 iOS 15.1，而需求是明确的 iOS 15.3+。
- 注入的 Safari 17/macOS UA 与真实 iOS 15 WebKit 能力不匹配。

## 本工程的对应处理

- 重建单一 iOS target，移除缺失界面、测试空 target、原作者 Team、macOS/xrOS 和错误 entitlement。
- 最低部署目标固定为 iOS 15.3。
- 只加载 `https://chatgpt.com/`。
- 使用 WebKit 默认持久数据存储，不读取或注入会话 Cookie。
- 移除 `NSAllowsArbitraryLoads`。
- 不注入网页 DOM/本地存储脚本，降低网页更新导致的脆弱性。
- UA 仅追加与旧 WebKit 相符的 Safari 产品标记。
- 补齐外部链接、弹窗、错误恢复、HTTP 附件下载和系统文件导出。
