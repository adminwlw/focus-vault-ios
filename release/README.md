# FocusVault 0.3.0 交付说明

日期：2026-11-06。本版重点升级本机隐藏照片/视频的导入、查找、浏览、原件处理与快速退出流程。按用户取舍，不扩容备份、不新增备份提醒，保留既有入口。

- 版本：`0.3.0`（build `4`）
- Bundle ID：`com.sim360.focusvault`
- 最低系统声明：iOS 16.0，仅 iPhone
- IPA：[FocusVault-0.3.0-unsigned.ipa](FocusVault-0.3.0-unsigned.ipa)，972,917 字节
- SHA-256：`a5b3829068fdaf1dd7bb3be9e676dcb9c782b7f5248c1272b65b438767901773`
- [校验文件](FocusVault-0.3.0-unsigned.ipa.sha256)、[完整升级说明](../UPGRADE_0.3.0.md)、[96 张截图索引](ui-screens-v030/README.md)

## 构建与打包来源

原生执行文件由 GitHub Actions [42177577220](https://github.com/adminwlw/focus-vault-ios/actions/runs/42177577220) 在 Xcode 16.4 / macOS 15 上构建，测试源码为 `441fbc68bad757de7778da9d089b5ffa95751d8a`。该次运行最终状态为 success，单元测试、四组 UI 测试和 Release 设备构建全部通过。

最后一项修改是 `0cf5a28c4a69229f343016b7552c9ae83c180f42` 中的隐私清单资源：为已有磁盘空间预检声明 `NSPrivacyAccessedAPICategoryDiskSpace / E174.1`。本地打包仅把这份资源同步进未签名 IPA，逐条比较确认其余 ZIP 条目内容及执行文件与 CI 原包完全相同；这不是重新编译或签名。源码中的同一清单已更新，后续正常 Xcode 构建会直接包含它。

- CI 原包 SHA-256：`f4c46a95a939c3299dd5c8b11ba1aa66f18374072ea71454f9dc4615d4369e1c`
- 执行文件 SHA-256：`9b572de0fc9738c5d059b948d0fb5f50ace1c1653d8028016c51ce08c1360d69`
- 唯一资源差异：`Payload/FocusVault.app/PrivacyInfo.xcprivacy`
- [产物核验记录](ci-v030/artifact-verification.json)、[CI 最终状态](ci-v030/run-status.json)、[CI 原包校验文件](ci-v030/ci-original-ipa.sha256)

## 本版功能

- 保留已完成的秒表替换、独立新建空相册、相册重命名/移动、当前相册导入、照片连续浏览、右滑锁定和后台锁定。
- 文件方式导入，后台按块加密、校验与导出；提供逐项进度、取消、未完成项目重试、可用空间预检和内容去重。最近删除中的相同文件恢复后复用。
- 导入结果区分新增、重复与失败；系统原件处理记录和时间存入加密索引，可主动重新检查。删除原件前再次验证已保存副本，系统确认后才记录删除结果。
- 搜索名称、备注、相册和日期；按周、月、年或指定日期定位。名称和备注可编辑，批量导出经确认后使用真实系统分享组件。
- 视频默认暂停和静音，网格显示时长；最近删除增加缩略图、预览、剩余天数与恢复。搜索、详情、相册、管理、原件和导入结果等场景提供便于触及的锁定入口。
- 首次设置后的真实入口练习、使用说明，以及可选面容 ID / 触控 ID。快捷认证由主动长按计时圆环触发，数字口令始终可以使用。
- 补齐面容认证和导出保存到系统照片的用途说明，隐私清单声明本机偏好设置与导入空间预检的用途。

## 验证结果

27 项单元测试全部通过，0 失败。覆盖新旧索引、相册、计时/秒表、写入失败回滚、加密备份兼容，以及本版新增的去重/最近删除复用、名称备注与搜索日期、损坏副本阻止删除原件、视频初始暂停静音、分块错误密钥/篡改/截断/追加和取消清理。

真实写入并往返验证一个 1 GiB（1,073,741,824 字节）二进制文件，内容指纹相同，该项在本次 CI 用时 8.335 秒。这不是 1 GiB 实际视频的播放或内存峰值验收。

| UI 配置 | 完整流程数 | 失败数 | 日志 |
| --- | ---: | ---: | --- |
| iPhone SE 第 3 代，浅色 | 2 | 0 | [原始日志](ci-v030/ui-tests-se-light.log) |
| iPhone SE 第 3 代，深色 | 2 | 0 | [原始日志](ci-v030/ui-tests-se-dark.log) |
| iPhone 16 Pro Max，浅色 | 2 | 0 | [原始日志](ci-v030/ui-tests-promax-light.log) |
| iPhone 16 Pro Max，深色 | 2 | 0 | [原始日志](ci-v030/ui-tests-promax-dark.log) |

两条流程覆盖首次创建、真实入口练习、计时与秒表、横屏、口令解锁、连续查看、新建/重命名相册、右滑退出、真实系统选图与导入、保留原件后的持久记录、后台锁定、计时中解锁、辅助字号，以及有效 H.264 视频、编辑、搜索、无结果、日期定位、最近删除预览恢复、认证设置、批量系统分享。

保留最终测试源码的 96 张原始截图，已复核两种尺寸和两种外观的关键页面。浏览示例为 DEBUG 夹具，系统选图使用实际模拟器照片库；认证设置截图只证明入口和不可用时的说明。系统分享截图只证明已生成副本并打开系统组件。

[单元测试日志](ci-v030/tests.log)和 [Release 设备构建日志](ci-v030/device-build.log)已归档。最终 IPA 的 ZIP 校验、版本、最低系统和设备族声明均通过；包含 Assets.car、编译图标、有效隐私清单和四项权限说明；不存在测试夹具入口、签名目录或描述文件。

## 主要文件

- [VaultStore.swift](../Sources/VaultStore.swift)：导入/导出、去重、原件处理、元数据、会话和失败回滚。
- [VaultMediaFile.swift](../Sources/VaultMediaFile.swift)：系统文件转移、分块加密与回读校验、媒体检查和后台任务。
- [VaultView.swift](../Sources/VaultView.swift) 与 [VaultUtilityViews.swift](../Sources/VaultUtilityViews.swift)：搜索、日期、批量操作、导入结果、原件记录、最近删除及锁定入口。
- [BiometricVaultKey.swift](../Sources/BiometricVaultKey.swift)、[SecurityServices.swift](../Sources/SecurityServices.swift) 与 [FocusView.swift](../Sources/FocusView.swift)：可选生物认证、会话保护和入口练习。
- [Models.swift](../Sources/Models.swift)、[Info.plist](../Resources/Info.plist) 与 [PrivacyInfo.xcprivacy](../Resources/PrivacyInfo.xcprivacy)：兼容模型、权限与隐私声明。
- [VaultUpgradeTests.swift](../Tests/VaultUpgradeTests.swift) 与 [FocusVaultUITests.swift](../UITests/FocusVaultUITests.swift)：文件、数据和真实系统组件回归。

## 安装与数据边界

这是未签名 IPA，普通 iPhone 需要 Apple Developer 签名和匹配的描述文件才能安装。本轮未进行签名、TestFlight 或 App Store 提交。

新版本兼容读取旧数组和 v2 索引，写入使用 v3 索引和新的分块媒体格式，不支持直接降级覆盖安装。覆盖升级时勿先卸载旧 App；卸载会删除本机数据。旧单块 AES-GCM 媒体仍按原格式读取，不能把新分块通路的表现用于宣传所有历史媒体的内存表现。

备份容量与格式保持原范围：媒体合计上限 256 MB，恢复文件上限 512 MB，没有新增扩容或提醒。Live Photo 成对资源完整迁移未实现。

仍需签名真机验收：真实面容/触控 ID、照片权限允许/拒绝/有限访问、iCloud 下载、系统原件实际删除与取消、相机、长视频与低存储、系统后台快照、VoiceOver，以及系统分享中的保存到照片和跨 App 接收。模拟器通过不替代这些结果。

0.1.x、0.2.0 IPA 和原有截图/日志作为历史产物保留；0.2.0 的原交付说明见 [历史说明](RELEASE_0.2.0.md)。当前使用本页的 0.3.0 交付包。
