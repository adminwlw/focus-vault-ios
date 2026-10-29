# Third-Party Notices

应用运行时未链接第三方 SDK。以下升级实现参考并改写了 MIT 许可项目中的最小必要模式；未复制项目名称、图标、素材或完整模块。

## arach/pomo

- 来源：<https://github.com/arach/pomo/blob/c3e0b7785b2407c84922bec047a80df9203ad36b/apps/ios/PomoiOS-App/Models/TimerManager.swift>
- 用途：暂停前按截止时间同步剩余秒数，继续时用暂停剩余秒数重建截止时间。
- Copyright (c) 2024 arach

## minimo-pro/minimo_video

- 来源：<https://github.com/minimo-pro/minimo_video/blob/87b494e105c6f5161047adf7ae07389110561c7d/ios/Runner/SceneDelegate.swift>
- 用途：请求 PhotoKit 读写权限、按本地资源标识定位全部原件，并通过系统照片库事务发起删除。
- Copyright (c) 2026 minimo.pro

## twostraws/SwiftUI-Agent-Skill

- 来源：<https://github.com/twostraws/SwiftUI-Agent-Skill/blob/f2920b63995263f57b3e198674e89a602efba6d2/swiftui-pro/references/data.md>
- 用途：SwiftUI 数字输入字段采用数字键盘，并保留项目所需的数据绑定语义。
- Copyright (c) 2026 Paul Hudson

上述三项适用以下 MIT License：

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 设计阶段参考但未复制

设计阶段还核对了 `EmilioPelaez/PrivateVault`、`KeychainAccess` 和 `GRDB.swift` 的实现范围与许可证；当前没有把这些项目的源码或运行时依赖加入应用。

构建工程使用 XcodeGen（MIT License）生成 Xcode 项目；XcodeGen 仅在构建阶段运行，不包含在应用二进制中：<https://github.com/yonaskolb/XcodeGen>。

