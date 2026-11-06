# FocusVault 0.3.0 实际 UI 截图

来自 Actions [42177577220](https://github.com/adminwlw/focus-vault-ios/actions/runs/42177577220)，源码 `441fbc68bad757de7778da9d089b5ffa95751d8a`。每种配置 24 张，共 96 张原始截图。

两条 UI 流程分别覆盖公开计时与首次导入，以及视频、组织、搜索、日期、误删恢复与批量导出。照片和两秒 H.264 视频为 DEBUG 测试夹具；系统选图使用实际模拟器照片库中的 App 图标。Release 不包含测试入口。

面容/触控 ID 截图只证明设置入口和不可用时的说明，不代表完成真实生物认证。系统分享页只证明已生成副本并打开系统组件，不代表跨 App 接收验收。辅助字号截图只覆盖计时器，不能作为全 App 无障碍验收。

| 场景 | SE 浅色 | SE 深色 | Pro Max 浅色 | Pro Max 深色 |
| --- | --- | --- | --- | --- |
| 首次设置口令 | [查看](se-light/01-first-run-password.png) | [查看](se-dark/01-first-run-password.png) | [查看](promax-light/01-first-run-password.png) | [查看](promax-dark/01-first-run-password.png) |
| 真实入口练习与锁定 | [查看](se-light/02-entry-practice-complete.png) | [查看](se-dark/02-entry-practice-complete.png) | [查看](promax-light/02-entry-practice-complete.png) | [查看](promax-dark/02-entry-practice-complete.png) |
| 公开计时器 | [查看](se-light/02-manual-timer-portrait.png) | [查看](se-dark/02-manual-timer-portrait.png) | [查看](promax-light/02-manual-timer-portrait.png) | [查看](promax-dark/02-manual-timer-portrait.png) |
| 横屏计时器 | [查看](se-light/03-manual-timer-landscape.png) | [查看](se-dark/03-manual-timer-landscape.png) | [查看](promax-light/03-manual-timer-landscape.png) | [查看](promax-dark/03-manual-timer-landscape.png) |
| 秒表计次 | [查看](se-light/03-stopwatch-lap.png) | [查看](se-dark/03-stopwatch-lap.png) | [查看](promax-light/03-stopwatch-lap.png) | [查看](promax-dark/03-stopwatch-lap.png) |
| 私人空间与照片网格 | [查看](se-light/04-private-vault-media.png) | [查看](se-dark/04-private-vault-media.png) | [查看](promax-light/04-private-vault-media.png) | [查看](promax-dark/04-private-vault-media.png) |
| 连续浏览与页码 | [查看](se-light/05-photo-detail-next.png) | [查看](se-dark/05-photo-detail-next.png) | [查看](promax-light/05-photo-detail-next.png) | [查看](promax-dark/05-photo-detail-next.png) |
| 新建空相册 | [查看](se-light/06-empty-album-created.png) | [查看](se-dark/06-empty-album-created.png) | [查看](promax-light/06-empty-album-created.png) | [查看](promax-dark/06-empty-album-created.png) |
| 当前相册导入入口 | [查看](se-light/07-album-import-entry.png) | [查看](se-dark/07-album-import-entry.png) | [查看](promax-light/07-album-import-entry.png) | [查看](promax-dark/07-album-import-entry.png) |
| 真实系统选图器 | [查看](se-light/08-system-photo-picker.png) | [查看](se-dark/08-system-photo-picker.png) | [查看](promax-light/08-system-photo-picker.png) | [查看](promax-dark/08-system-photo-picker.png) |
| 导入结果与原件选择 | [查看](se-light/09-import-original-choice.png) | [查看](se-dark/09-import-original-choice.png) | [查看](promax-light/09-import-original-choice.png) | [查看](promax-dark/09-import-original-choice.png) |
| 导入当前相册 | [查看](se-light/10-imported-into-album.png) | [查看](se-dark/10-imported-into-album.png) | [查看](promax-light/10-imported-into-album.png) | [查看](promax-dark/10-imported-into-album.png) |
| 后台后保持锁定 | [查看](se-light/11-background-locked.png) | [查看](se-dark/11-background-locked.png) | [查看](promax-light/11-background-locked.png) | [查看](promax-dark/11-background-locked.png) |
| 计时器辅助字号 | [查看](se-light/12-large-text-timer.png) | [查看](se-dark/12-large-text-timer.png) | [查看](promax-light/12-large-text-timer.png) | [查看](promax-dark/12-large-text-timer.png) |
| 持久化的原件处理记录 | [查看](se-light/13-original-state-retained.png) | [查看](se-dark/13-original-state-retained.png) | [查看](promax-light/13-original-state-retained.png) | [查看](promax-dark/13-original-state-retained.png) |
| 视频默认暂停和静音 | [查看](se-light/14-video-paused-muted.png) | [查看](se-dark/14-video-paused-muted.png) | [查看](promax-light/14-video-paused-muted.png) | [查看](promax-dark/14-video-paused-muted.png) |
| 编辑名称和备注后重新打开 | [查看](se-light/15-renamed-video.png) | [查看](se-dark/15-renamed-video.png) | [查看](promax-light/15-renamed-video.png) | [查看](promax-dark/15-renamed-video.png) |
| 按备注搜索与底部锁定 | [查看](se-light/16-search-note.png) | [查看](se-dark/16-search-note.png) | [查看](promax-light/16-search-note.png) | [查看](promax-dark/16-search-note.png) |
| 日期定位 | [查看](se-light/17-date-picker.png) | [查看](se-dark/17-date-picker.png) | [查看](promax-light/17-date-picker.png) | [查看](promax-dark/17-date-picker.png) |
| 搜索无结果 | [查看](se-light/17-filter-no-results.png) | [查看](se-dark/17-filter-no-results.png) | [查看](promax-light/17-filter-no-results.png) | [查看](promax-dark/17-filter-no-results.png) |
| 最近删除缩略图和天数 | [查看](se-light/18-trash-thumbnail-days.png) | [查看](se-dark/18-trash-thumbnail-days.png) | [查看](promax-light/18-trash-thumbnail-days.png) | [查看](promax-dark/18-trash-thumbnail-days.png) |
| 预览后恢复 | [查看](se-light/19-trash-restored.png) | [查看](se-dark/19-trash-restored.png) | [查看](promax-light/19-trash-restored.png) | [查看](promax-dark/19-trash-restored.png) |
| 快捷认证设置与口令回退说明 | [查看](se-light/20-biometric-settings.png) | [查看](se-dark/20-biometric-settings.png) | [查看](promax-light/20-biometric-settings.png) | [查看](promax-dark/20-biometric-settings.png) |
| 真实系统批量分享页 | [查看](se-light/21-batch-export-share.png) | [查看](se-dark/21-batch-export-share.png) | [查看](promax-light/21-batch-export-share.png) | [查看](promax-dark/21-batch-export-share.png) |
