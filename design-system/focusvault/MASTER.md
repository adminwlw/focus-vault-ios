# FocusVault Native Design System

本文件是源码实现的快速约束。完整交互和适配说明见项目根目录 `UI_DESIGN.md`。

## 平台

- iOS 16+，iPhone only
- SwiftUI 为主；仅在系统组件能明显改善行为时桥接 UIKit
- SF 系统字体、SF Symbols、系统语义色

## 视觉令牌

| 用途 | 规则 |
| --- | --- |
| 主背景 | `Color(uiColor: .systemBackground)` 或分组页的 `systemGroupedBackground` |
| 次级表面 | `secondarySystemBackground` / `.background` |
| 主操作 | `Color.accentColor` + `.borderedProminent` |
| 次要操作 | `.bordered` 或系统 Menu |
| 危险操作 | `role: .destructive`，并二次确认 |
| 正文 | `.body`；说明 `.footnote` / `.caption` + `.secondary` |
| 圆角 | 卡片 16 pt，系统弹层和按钮沿用系统默认 |
| 间距 | 4 / 8 / 12 / 16 / 20 / 24 / 32 pt |

## 组件规则

- 导航使用 `NavigationStack`、系统大标题或行内标题。
- 表单使用 `Form`/`List`；照片使用自适应 `LazyVGrid`。
- 触控区域至少 44 pt；不以颜色或动画作为唯一提示。
- 使用 `ViewThatFits` 或 `AnyLayout` 支持大字号；避免固定行高。
- 私密照片查看使用 `UIScrollView` 原生缩放和拖动。
- 页面使用安全区域；只有相机、后台遮挡和全屏媒体背景可 `ignoresSafeArea`。

## 禁止项

- Google Fonts、自定义网页字体、CSS 令牌
- 紫色 AI 渐变、玻璃拟态营销卡片、装饰性 emoji
- 固定三列照片网格、固定文本高度、仅靠手势才能发现的主要操作
- 在公共设置、通知、搜索索引或日志中暴露私人空间内容
