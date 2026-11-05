# FocusVault 0.2.0 构建产物

本轮交付包对应源码提交 `2f01d2a9ed74b69a6194566ce49f9d34b21a2090`，由 GitHub Actions 运行 [42073869608](https://github.com/adminwlw/focus-vault-ios/actions/runs/42073869608) 在 Xcode 16.4 / macOS 15 上构建。运行最终结论为 success，原始日志中的单元测试、两组 UI 测试和 Release 设备构建均通过。

- 版本：`0.2.0`（build `3`）
- Bundle ID：`com.sim360.focusvault`
- 最低系统：iOS 16.0，仅 iPhone
- IPA：[FocusVault-0.2.0-unsigned.ipa](FocusVault-0.2.0-unsigned.ipa)，701,005 字节
- SHA-256：`69ab3e9de3b132f3f216d8ab60d9f0ac984fc43967f78c0a6057443c491795b4`
- 校验文件：[FocusVault-0.2.0-unsigned.ipa.sha256](FocusVault-0.2.0-unsigned.ipa.sha256)

## 本轮升级

记录页改为支持开始、暂停、计次、复位和重启恢复的秒表。私人空间增加独立空相册、重命名和删除分类、按当前相册导入、可见分类筛选、批量全选、媒体连续查看和新视频缩略图。私人空间内容区右滑或点击锁定按钮可退出，后台锁定；运行中的计时也能输入口令进入私人空间。

修复索引写入失败的内存状态、备份恢复部分覆盖、Keychain 更新、导入退出后的会话状态和临时 inactive 中断问题。完整范围、证据和限制见 [产品审计报告](../PRODUCT_AUDIT.md)。

## 验证结果

- 17 个单元测试全部通过、0 失败，覆盖加密/口令/计时、秒表、空相册、旧索引兼容、失败回滚、不同密钥恢复及损坏/重复备份等。
- Release / iphoneos 无签名设备构建通过。
- iPhone SE（第 3 代，浅色）和 iPhone 16 Pro Max（深色）各通过一条完整 UI 流程：首次设置、秒表、横竖屏、口令解锁、照片连续查看、新建/重命名相册、右滑退出、真实系统照片选取及导入当前相册、选择保留系统原件、后台锁定、计时中解锁、辅助字号。
- [截图索引](ui-screens-v020/README.md) 包含本轮最终源码的双尺寸共 26 张截图，已逐一检查。照片浏览示例使用 DEBUG 夹具；系统选图与导入另使用实际模拟器照片库。Release 二进制中不包含测试夹具入口。
- IPA 已解包复核，版本、最低系统、iPhone 设备族声明正确，包含 `Assets.car`、编译后 App 图标和 `PrivacyInfo.xcprivacy`。本地 IPA 哈希与 CI 校验文件相同。
- `ci-v020/` 保存四份原始构建/测试日志；`audit/baseline/` 保存本次重新运行旧版捕获的三张基线截图。

`FocusVault-0.1.0-unsigned.ipa` 和 `FocusVault-0.1.1-unsigned.ipa` 作为历史产物保留；本轮使用 `0.2.0`。

## 安装与数据边界

这是未签名 IPA，不能直接安装到普通 iPhone。真机安装需 Apple Developer 证书和匹配的描述文件；本轮没有完成签名、TestFlight 或 App Store 提交。

升级兼容读取旧索引，但新版写入的独立相册索引不支持直接降级给旧版使用。升级前保留已有加密备份，勿先卸载旧 App。导入是复制，系统原件仅在用户选择删除并经系统确认后处理；系统“最近删除”和 iCloud 的影响需自行留意。

本版备份仍使用内存格式：备份媒体总量上限 256 MB，恢复文件上限 512 MB；尚未实现大库流式/分卷备份和 Live Photo 成对资源完整保存。

仍需已签名真机验证相机、有限照片权限、iCloud 下载、系统原件实际删除/取消、长视频与内存峰值、系统后台快照、真实跨设备恢复和 VoiceOver。模拟器通过不替代这些验收。
