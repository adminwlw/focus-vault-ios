import SwiftUI

struct VaultImportResultView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State var result: VaultImportResult
    let onLock: () -> Void
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var message: String?

    private var resultIDs: Set<UUID> { Set(result.importedIDs + result.duplicateIDs) }
    private var resultItems: [VaultItem] { store.activeItems.filter { resultIDs.contains($0.id) } }
    private var originalIDs: Set<UUID> {
        Set(resultItems.filter { $0.sourceIdentifier != nil && $0.originalState != .deletionSucceeded }.map(\.id))
    }

    var body: some View {
        NavigationStack {
            resultList
            .navigationTitle("导入结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(store.isBusy || deleting) } }
            .safeAreaInset(edge: .bottom) { VaultLockBar(onLock: onLock) }
            .confirmationDialog("删除这 \(originalIDs.count) 项系统原件？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("请求系统删除", role: .destructive) {
                    requestDeletion()
                }
            } message: { Text("App 中的加密副本会保留，系统会处理权限和确认。") }
            .alert("处理结果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private var resultList: some View {
        List {
            summarySection
            if !result.failures.isEmpty {
                Section("未完成") {
                    ForEach(result.failures.indices, id: \.self) { index in
                        Text(result.failures[index]).font(.footnote)
                    }
                }
            }
            originalsSection
        }
    }

    private var summarySection: some View {
        Section {
            LabeledContent("新导入", value: "\(result.importedIDs.count) 项")
            LabeledContent("已存在，未重复保存", value: "\(result.duplicateIDs.count) 项")
            if result.cancelled { Text("导入已取消，成功项目已保留。未完成项目可重试。") }
            if let progress = store.importProgress {
                ProgressView("已处理 \(progress.completed) / \(progress.total) 项")
                Button("取消导入") { store.cancelImport() }
            }
            if store.retryCount > 0 {
                Button("重试未完成的 \(store.retryCount) 项") { Task { result = await store.retryImport() } }
                    .accessibilityIdentifier("import-retry")
            }
        } footer: { Text("加密副本已校验保存。已有的重复项目会直接复用；最近删除中的同一项目会恢复。") }
    }

    private var originalsSection: some View {
        Section {
            ForEach(resultItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).lineLimit(2)
                    Text(item.originalStatus).font(.caption).foregroundStyle(.secondary)
                }
            }
            if !originalIDs.isEmpty {
                Button("删除系统照片中的原件", role: .destructive) { confirmDelete = true }
                    .disabled(store.isBusy || deleting)
            }
            Button("保留系统原件") { dismiss() }.disabled(store.isBusy || deleting)
        } header: { Text("系统原件") } footer: {
            Text("删除由 iOS 确认，可能影响 iCloud 其他设备；系统“最近删除”需要你自行核对。之后可在私人空间菜单“系统原件”查看上次处理结果。")
        }
    }

    private func requestDeletion() {
        let ids = originalIDs
        deleting = true
        Task {
            defer { deleting = false }
            do { try await store.deleteOriginals(for: ids); message = "系统删除请求已完成。请自行核对系统“最近删除”。" }
            catch { message = error.localizedDescription }
        }
    }
}

struct VaultOriginalsView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let onLock: () -> Void
    @State private var onlyPending = true
    @State private var deletingItem: VaultItem?
    @State private var checking = false
    @State private var message: String?

    private var visible: [VaultItem] { onlyPending ? store.pendingOriginalItems : store.activeItems }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("显示", selection: $onlyPending) {
                        Text("待确认").tag(true)
                        Text("全部记录").tag(false)
                    }.pickerStyle(.segmented)
                    Text("状态代表最近一次操作或检查。无法访问、找不到原件时只标记为未确认，不代表已彻底清理。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(checking ? "正在检查…" : "重新检查原件状态") {
                        checking = true
                        Task {
                            defer { checking = false }
                            do { try await store.checkOriginals() } catch { message = error.localizedDescription }
                        }
                    }.disabled(checking)
                } footer: { Text("主动检查需要照片库权限，系统将询问授权。不会自动删除任何照片。") }
                if visible.isEmpty { Text("没有待确认的项目").foregroundStyle(.secondary) }
                ForEach(visible) { item in
                    HStack(alignment: .top, spacing: 12) {
                        VaultGridCell(item: item).frame(width: 58, height: 58).clipped().accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title).lineLimit(2)
                            Text(item.originalStatus).font(.caption).foregroundStyle(.secondary)
                            if let checked = item.originalCheckedAt {
                                Text("更新于 \(checked.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            if item.sourceIdentifier != nil, item.originalState != .deletionSucceeded {
                                Button("请求删除系统原件", role: .destructive) { deletingItem = item }
                                    .font(.caption)
                            }
                        }
                    }
                }
                Section {
                    Text("系统“最近删除”中的项目可能仍保留一段时间。请在系统“照片”中自行核对所选项目；本 App 不会清空系统最近删除。")
                        .font(.footnote)
                }
            }
            .navigationTitle("系统原件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .safeAreaInset(edge: .bottom) { VaultLockBar(onLock: onLock) }
            .confirmationDialog("请求系统删除原件？", isPresented: Binding(get: { deletingItem != nil }, set: { if !$0 { deletingItem = nil } }), titleVisibility: .visible) {
                Button("请求系统删除", role: .destructive) {
                    guard let item = deletingItem else { return }
                    deletingItem = nil
                    Task {
                        do { try await store.deleteOriginals(for: [item.id]) }
                        catch { message = error.localizedDescription }
                    }
                }
            } message: { Text("加密副本保留。删除会影响启用 iCloud 照片的其他设备，仍需自行核对系统最近删除。") }
            .alert("处理结果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }
}

struct VaultLockBar: View {
    let onLock: () -> Void
    var body: some View {
        Button(action: onLock) { Label("锁定退出", systemImage: "lock.fill").frame(maxWidth: .infinity, minHeight: 44) }
            .accessibilityIdentifier("modal-lock")
            .padding(.horizontal).padding(.vertical, 4).background(.regularMaterial)
    }
}

struct VaultMetadataEditor: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let item: VaultItem
    let onLock: () -> Void
    @State private var name = ""
    @State private var note = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") { TextField("使用原文件名", text: $name).accessibilityIdentifier("media-display-name") }
                Section("备注") { TextEditor(text: $note).frame(minHeight: 120).accessibilityIdentifier("media-note") }
                Section("文件信息") {
                    LabeledContent("原文件名", value: item.originalName)
                    LabeledContent("大小", value: ByteCountFormatter.string(fromByteCount: Int64(item.byteCount), countStyle: .file))
                    LabeledContent("导入日期", value: item.importedAt.formatted(date: .abbreviated, time: .shortened))
                    Text(item.originalStatus).font(.footnote)
                }
            }
            .navigationTitle("名称与备注").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { VaultLockBar(onLock: onLock) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try store.editMetadata(item.id, name: name, note: note); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }
            .onAppear { name = item.displayName ?? ""; note = item.note ?? "" }
            .alert("无法保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

struct VaultBiometricSettings: View {
    @EnvironmentObject private var authStore: VaultAuthStore
    @State private var working = false
    @State private var error: String?
    var body: some View {
        Form {
            Section {
                Toggle("面容 ID / 触控 ID 快捷进入", isOn: Binding(get: { authStore.biometricsEnabled }, set: { enabled in
                    working = true
                    Task {
                        defer { working = false }
                        do { try await authStore.setBiometricsEnabled(enabled) }
                        catch { self.error = error.localizedDescription }
                    }
                }))
                .disabled(working || (!BiometricVaultKey.available && !authStore.biometricsEnabled))
                .accessibilityIdentifier("vault-biometric-toggle")
                if working { ProgressView("正在设置…") }
            } footer: {
                Text("开启后，长按公开计时器的圆环即可主动认证。打开 App 不会自动弹出认证；原数字口令始终可以使用。")
            }
            Section {
                Text(BiometricVaultKey.available ? "更改设备已录入的面容或指纹后，需要用原口令进入并重新开启。" : "请先在系统设置中启用面容 ID 或触控 ID。当前仍可使用原口令。")
                    .font(.footnote)
            }
        }
        .navigationTitle("快捷认证").navigationBarTitleDisplayMode(.inline)
        .alert("快捷认证", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct VaultUsageHelp: View {
    var body: some View {
        List {
            Section("进入私人空间") {
                Text("在计时器的计时时长框输入完整数字口令，再点键盘“确认”。运行中的计时不会被打断。")
                Text("普通分钟数用于计时。口令输错后连续重试会短暂等待，稍后再试即可。")
                Text("开启快捷认证后可长按计时圆环。认证只由你主动触发。")
            }
            Section("照片和视频") {
                Text("导入是复制。导入结果与“系统原件”页面显示上次处理结果；系统最近删除需要自行核对。")
                Text("重复媒体会复用已有项目；最近删除中的同一项目会恢复。搜索支持名称、备注、相册和日期，也可单独选择日期。")
                Text("视频默认暂停且静音，点击播放与声音按钮后才播放或开启声音。")
            }
            Section("退出与导出") {
                Text("相册内容区右滑可锁定；照片详情、管理页底部也有锁定退出。照片缩放和系统返回手势保持原有行为。")
                Text("导出会在文件或其他 App 留下可见副本；批量导出前请确认保存位置。")
            }
        }
        .navigationTitle("使用说明").navigationBarTitleDisplayMode(.inline)
    }
}
