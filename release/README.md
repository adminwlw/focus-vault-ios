# FocusVault 0.1.1 构建产物

本目录当前交付包对应源码提交 `4afe6e535dcf2b66c12d2780f1c2cfc91b3bf64c`，由 GitHub Actions 运行 [40830876682](https://github.com/adminwlw/focus-vault-ios/actions/runs/40830876682) 在 Xcode 16.4 / macOS 15 上构建。

- 版本：`0.1.1`（build `2`）
- Bundle ID：`com.sim360.focusvault`
- 最低系统：iOS 16.0，仅 iPhone
- IPA：`FocusVault-0.1.1-unsigned.ipa`
- SHA-256：`37a0d9dbcbadb8660261e673668de1c91d3437e6077f62bbd40d30c850be23ca`

## 验证结果

- 7 个单元测试全部通过，新增设置时长、暂停和继续的可控时钟回归测试。
- Release / iphoneos 无签名设备构建通过。
- iPhone SE（第 3 代）与 iPhone 16 Pro Max 的首启、数字键盘、计时、横竖屏、错误输入和私人空间解锁 UI 流程均通过。
- IPA 已解包复核，包含 `Assets.car`、编译后的 App 图标、`PrivacyInfo.xcprivacy`、正确版本号与 iPhone 设备族声明。
- `ci/` 保存本轮四份原始构建/测试日志；`ui-screens/` 保存两种尺寸各四张稳定截图。

`FocusVault-0.1.0-unsigned.ipa` 仅作为上一版本历史产物保留；本轮测试应使用 `0.1.1`。

这是未签名 IPA，不能直接安装到普通 iPhone。真机安装仍需 Apple Developer 证书和匹配的描述文件；照片权限、相机、后台锁定以及跨设备备份恢复仍须在已签名真机包上完成最终验收。
