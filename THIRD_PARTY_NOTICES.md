# Third-Party Notices

应用运行时未链接第三方 SDK 或代码库。

设计阶段核对了 `arach/pomo`、`EmilioPelaez/PrivateVault`、`KeychainAccess` 和 `GRDB.swift` 的实现范围与许可证；当前只参考交互和模块边界，没有复制其源码或把它们加入运行时依赖。若后续引入代码，必须固定版本并在本文件保留对应版权与许可证正文。

构建工程使用 XcodeGen（MIT License）生成 Xcode 项目；XcodeGen 仅在构建阶段运行，不包含在应用二进制中：<https://github.com/yonaskolb/XcodeGen>。

