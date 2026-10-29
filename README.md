# FocusVault iOS

`专注计时`是一款 iPhone 原生 SwiftUI App：公开界面提供专注计时与记录，用户主动设置口令后可使用本机私人空间。

## 已实现

- 25 分钟专注、5 分钟休息和自定义时长；暂停、继续、提前结束、后台恢复与本地通知。
- 本地专注记录、汇总、搜索，以及由完整口令触发的私人空间入口。
- Keychain 口令验证和媒体密钥，AES-GCM 加密媒体与索引，退到后台立即锁定并遮挡任务切换快照。
- 系统照片选择器批量导入、应用内相机、加密缩略图、照片缩放、视频播放、收藏、批量选择、相册分类、拍摄/导入时间排序和导出确认。
- 30 天最近删除、恢复和永久删除。
- 使用独立备份密码的加密备份，以及跨设备恢复入口。
- Apple 隐私清单、商店披露文案和审核访问说明。
- iOS 17+，仅 iPhone；不包含账号、开发者云端、广告或订阅。

## 构建

项目文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成：

```bash
brew install xcodegen
xcodegen generate
open FocusVault.xcodeproj
```

GitHub Actions 会运行单元测试并生成未签名 IPA。未签名 IPA 只能验证构建产物，不能直接安装到普通 iPhone。真机安装需要为 `com.sim360.focusvault` 配置 Apple Developer 证书和匹配的描述文件，或由测试者使用自己的开发者身份重新签名。

## 数据边界

私人媒体默认仅保存在 App 容器内。导入是复制操作，不会自动删除系统“照片”中的原件。卸载 App 前必须导出加密备份；口令与备份密码都无法由开发者找回。

