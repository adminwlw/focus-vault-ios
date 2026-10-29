import AVKit
import PhotosUI
import SwiftUI
import UIKit

struct VaultView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedAlbum: String?
    @State private var favoritesOnly = false
    @State private var showCamera = false
    @State private var showTrash = false
    @State private var showManagement = false
    @State private var albumTarget: VaultItem?
    @State private var newAlbumName = ""
    let onLock: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    private var visibleItems: [VaultItem] {
        store.activeItems.filter { item in
            (!favoritesOnly || item.isFavorite) && (selectedAlbum == nil || item.albumName == selectedAlbum)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleItems.isEmpty {
                    ContentUnavailableView {
                        Label(emptyTitle, systemImage: favoritesOnly ? "heart" : "photo.on.rectangle.angled")
                    } description: {
                        Text(emptyDescription)
                    } actions: {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 50, matching: .any(of: [.images, .videos])) {
                            Label("导入照片或视频", systemImage: "photo.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(visibleItems) { item in
                                NavigationLink(value: item) {
                                    VaultGridCell(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        tryAction { try store.toggleFavorite(item) }
                                    } label: {
                                        Label(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "heart.slash" : "heart")
                                    }
                                    albumMenu(for: item)
                                    Button(role: .destructive) {
                                        tryAction { try store.moveToTrash(item) }
                                    } label: {
                                        Label("移到最近删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .background(Color(uiColor: .systemBackground))
                }
            }
            .navigationTitle(selectedAlbum ?? (favoritesOnly ? "收藏" : "私人空间"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: VaultItem.self) { item in
                VaultDetailView(itemID: item.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onLock) {
                        Label("锁定", systemImage: "lock")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 50, matching: .any(of: [.images, .videos])) {
                        Image(systemName: "plus")
                    }
                    Menu {
                        Button {
                            showCamera = true
                        } label: {
                            Label("拍照", systemImage: "camera")
                        }
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                        Divider()
                        Button {
                            selectedAlbum = nil
                            favoritesOnly = false
                        } label: {
                            Label("全部项目", systemImage: "square.grid.3x3")
                        }
                        Button {
                            selectedAlbum = nil
                            favoritesOnly = true
                        } label: {
                            Label("收藏", systemImage: "heart")
                        }
                        if !store.albums.isEmpty {
                            Menu("相册") {
                                ForEach(store.albums, id: \.self) { album in
                                    Button(album) {
                                        favoritesOnly = false
                                        selectedAlbum = album
                                    }
                                }
                            }
                        }

                        Divider()
                        Button {
                            showTrash = true
                        } label: {
                            Label("最近删除", systemImage: "trash")
                        }
                        Button {
                            showManagement = true
                        } label: {
                            Label("管理私人空间", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if store.isBusy {
                    ZStack {
                        Color.black.opacity(0.18).ignoresSafeArea()
                        ProgressView("正在安全导入…")
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await store.importSelections(newItems)
                    pickerItems = []
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    tryAction { try store.importCapturedImage(image) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showTrash) {
                RecentlyDeletedView()
            }
            .sheet(isPresented: $showManagement) {
                VaultManagementView()
            }
            .alert("新建相册", isPresented: Binding(
                get: { albumTarget != nil },
                set: { if !$0 { albumTarget = nil; newAlbumName = "" } }
            )) {
                TextField("相册名称", text: $newAlbumName)
                Button("取消", role: .cancel) {
                    albumTarget = nil
                    newAlbumName = ""
                }
                Button("创建并移动") {
                    if let item = albumTarget {
                        tryAction { try store.assign(item, toAlbum: newAlbumName) }
                    }
                    albumTarget = nil
                    newAlbumName = ""
                }
                .disabled(newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .alert("操作失败", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "未知错误")
            }
        }
    }

    @ViewBuilder
    private func albumMenu(for item: VaultItem) -> some View {
        Menu {
            Button("不属于任何相册") {
                tryAction { try store.assign(item, toAlbum: nil) }
            }
            ForEach(store.albums, id: \.self) { album in
                Button(album) {
                    tryAction { try store.assign(item, toAlbum: album) }
                }
            }
            Button("新建相册…") {
                albumTarget = item
            }
        } label: {
            Label("移动到相册", systemImage: "folder")
        }
    }

    private var emptyTitle: String {
        if favoritesOnly { return "还没有收藏" }
        if let selectedAlbum { return "“\(selectedAlbum)”为空" }
        return "私人空间为空"
    }

    private var emptyDescription: String {
        if favoritesOnly { return "收藏的项目会集中显示在这里。" }
        return "从系统照片中选择，或使用相机直接拍摄。导入完成不等于系统原件已删除。"
    }

    private func tryAction(_ action: () throws -> Void) {
        do { try action() } catch { store.errorMessage = error.localizedDescription }
    }
}

private struct VaultGridCell: View {
    @EnvironmentObject private var store: VaultStore
    let item: VaultItem
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(Color(uiColor: .secondarySystemBackground))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: item.mediaKind == .video ? "play.rectangle.fill" : "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .clipped()

            HStack(spacing: 4) {
                if item.isFavorite {
                    Image(systemName: "heart.fill")
                }
                if item.mediaKind == .video {
                    Image(systemName: "video.fill")
                }
            }
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(6)
            .shadow(radius: 2)
        }
        .task(id: item.id) {
            guard item.mediaKind == .photo else { return }
            image = try? UIImage(data: store.data(for: item))
        }
        .accessibilityLabel(item.mediaKind == .photo ? "照片" : "视频")
        .accessibilityValue(item.importedAt.formatted(date: .abbreviated, time: .shortened))
    }
}

private struct VaultDetailView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var confirmDelete = false
    @State private var loadError: String?

    private var item: VaultItem? {
        store.items.first { $0.id == itemID }
    }

    var body: some View {
        Group {
            if let item {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if item.mediaKind == .photo, let image {
                        ZoomableImage(image: image)
                    } else if item.mediaKind == .video, let player {
                        VideoPlayer(player: player)
                            .onAppear { player.play() }
                            .onDisappear { player.pause() }
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .navigationTitle(item.originalName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbarBackground(.black, for: .navigationBar)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            prepareShare(item)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Menu {
                            Button {
                                tryAction { try store.toggleFavorite(item) }
                            } label: {
                                Label(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "heart.slash" : "heart")
                            }
                            Button(role: .destructive) {
                                confirmDelete = true
                            } label: {
                                Label("移到最近删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .task(id: item.id) { load(item) }
            } else {
                ContentUnavailableView("项目不存在", systemImage: "exclamationmark.triangle")
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .confirmationDialog("移到最近删除？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("移到最近删除", role: .destructive) {
                guard let item else { return }
                tryAction {
                    try store.moveToTrash(item)
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("项目将在 30 天后自动永久删除。")
        }
        .alert("无法打开", isPresented: Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("好", role: .cancel) { loadError = nil }
        } message: {
            Text(loadError ?? "未知错误")
        }
    }

    private func load(_ item: VaultItem) {
        do {
            if item.mediaKind == .photo {
                guard let decoded = UIImage(data: try store.data(for: item)) else {
                    throw ValidationError("照片格式无法读取。")
                }
                image = decoded
            } else {
                let url = try store.temporaryExport(for: item)
                exportURL = url
                player = AVPlayer(url: url)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func prepareShare(_ item: VaultItem) {
        do {
            exportURL = try store.temporaryExport(for: item)
            showShare = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func tryAction(_ action: () throws -> Void) {
        do { try action() } catch { loadError = error.localizedDescription }
    }
}

private struct ZoomableImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value.magnification, 1), 5)
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = scale > 1 ? 1 : 2
                    lastScale = scale
                }
            }
    }
}

private struct RecentlyDeletedView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEmpty = false

    var body: some View {
        NavigationStack {
            List {
                if store.deletedItems.isEmpty {
                    ContentUnavailableView("最近删除为空", systemImage: "trash")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(store.deletedItems) { item in
                        HStack {
                            Image(systemName: item.mediaKind == .photo ? "photo" : "video")
                                .frame(width: 30)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.originalName)
                                if let deletedAt = item.deletedAt {
                                    Text("删除于 \(deletedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Menu {
                                Button("恢复") { try? store.restore(item) }
                                Button("永久删除", role: .destructive) { try? store.deletePermanently(item) }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("最近删除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                if !store.deletedItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("全部删除", role: .destructive) { confirmEmpty = true }
                    }
                }
            }
            .confirmationDialog("永久删除全部项目？", isPresented: $confirmEmpty, titleVisibility: .visible) {
                Button("永久删除", role: .destructive) { try? store.emptyTrash() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作无法撤销。")
            }
        }
    }
}

private struct VaultManagementView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("备份与恢复") {
                    NavigationLink("创建加密备份") {
                        CreateBackupView()
                    }
                    NavigationLink("从备份恢复") {
                        RestoreBackupView()
                    }
                    Text("备份密码独立于私人空间口令。恢复需要同时持有备份文件和备份密码。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("安全") {
                    NavigationLink("修改口令") {
                        ChangePasscodeView()
                    }
                }
                Section("存储") {
                    LabeledContent("项目", value: "\(store.activeItems.count)")
                    LabeledContent("最近删除", value: "\(store.deletedItems.count)")
                }
            }
            .navigationTitle("管理私人空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct CreateBackupView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var password = ""
    @State private var confirmation = ""
    @State private var backupURL: URL?
    @State private var showShare = false
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section("备份密码") {
                SecureField("至少 8 个字符", text: $password)
                SecureField("再次输入", text: $confirmation)
            }
            Section {
                Button {
                    createBackup()
                } label: {
                    HStack {
                        Text("创建备份文件")
                        Spacer()
                        if isWorking { ProgressView() }
                    }
                }
                .disabled(isWorking || password.count < 8 || password != confirmation)
            } footer: {
                Text("备份包含私人媒体、相册分类和必要元数据。请把文件保存在安全位置。")
            }
        }
        .navigationTitle("创建备份")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let backupURL {
                ShareSheet(items: [backupURL])
            }
        }
        .alert("无法创建备份", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private func createBackup() {
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                backupURL = try store.createBackup(password: password)
                showShare = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct RestoreBackupView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var selectedURL: URL?
    @State private var password = ""
    @State private var showImporter = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        Form {
            Section("备份文件") {
                Button {
                    showImporter = true
                } label: {
                    Label(selectedURL?.lastPathComponent ?? "选择备份文件", systemImage: "doc.badge.plus")
                }
            }
            Section("备份密码") {
                SecureField("输入备份密码", text: $password)
            }
            Section {
                Button("验证并恢复") { restore() }
                    .disabled(selectedURL == nil || password.isEmpty)
            } footer: {
                Text("同一项目会被备份版本替换；其他现有项目会保留。恢复完成前不会删除当前内容。")
            }
        }
        .navigationTitle("恢复备份")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.focusVaultBackup, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result { selectedURL = urls.first }
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .alert("恢复结果", isPresented: Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )) {
            Button("好", role: .cancel) { successMessage = nil }
        } message: {
            Text(successMessage ?? "")
        }
        .alert("无法恢复", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private func restore() {
        guard let selectedURL else { return }
        do {
            try store.restoreBackup(from: selectedURL, password: password)
            successMessage = "恢复完成，共有 \(store.activeItems.count) 个可用项目。"
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ChangePasscodeView: View {
    @EnvironmentObject private var authStore: VaultAuthStore
    @State private var current = ""
    @State private var new = ""
    @State private var confirmation = ""
    @State private var hint = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                SecureField("当前口令", text: $current)
                SecureField("新口令", text: $new)
                SecureField("再次输入新口令", text: $confirmation)
                TextField("新提示词（可选）", text: $hint)
            }
            Button("修改口令") { change() }
                .disabled(current.isEmpty || new.count < 6 || new != confirmation)
        }
        .navigationTitle("修改口令")
        .navigationBarTitleDisplayMode(.inline)
        .alert("修改口令", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func change() {
        do {
            try authStore.changePasscode(current: current, new: new, confirmation: confirmation, hint: hint)
            current = ""
            new = ""
            confirmation = ""
            message = "口令已更新。私人媒体无需重新导入。"
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
