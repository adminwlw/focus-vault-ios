import AVKit
import PhotosUI
import SwiftUI
import UIKit

private enum VaultSortOrder: String, CaseIterable, Identifiable {
    case importedNewest = "最近导入"
    case capturedNewest = "最近拍摄"
    var id: Self { self }
}

struct VaultView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var selectedAlbum: String?
    @State private var path: [VaultItem] = []
    @State private var showAlbums = false
    @State private var showNewAlbum = false
    @State private var mediaFilter: VaultMediaKind?
    @State private var favoritesOnly = false
    @State private var showCamera = false
    @State private var showTrash = false
    @State private var showManagement = false
    @State private var albumTargets: Set<UUID> = []
    @State private var newAlbumName = ""
    @State private var sortOrder: VaultSortOrder = .importedNewest
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var confirmBatchDelete = false
    @State private var importedSystemAssetIDs: [String] = []
    @State private var confirmDeleteSystemOriginals = false
    @State private var importNote = ""
    let onLock: () -> Void

    private var columns: [GridItem] {
        let minimum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 140 : 108
        return [GridItem(.adaptive(minimum: minimum, maximum: 220), spacing: 2)]
    }

    private var visibleItems: [VaultItem] {
        let filtered = store.activeItems.filter { item in
            (!favoritesOnly || item.isFavorite) && (selectedAlbum == nil || item.albumName == selectedAlbum)
                && (mediaFilter == nil || item.mediaKind == mediaFilter)
        }
        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .importedNewest:
                lhs.importedAt > rhs.importedAt
            case .capturedNewest:
                (lhs.capturedAt ?? lhs.importedAt) > (rhs.capturedAt ?? rhs.importedAt)
            }
        }
    }

    var body: some View {
        presentedNavigation
            .onChange(of: store.albums) { names in
                if let selectedAlbum, !names.contains(selectedAlbum) {
                    self.selectedAlbum = nil
                    finishSelection()
                }
            }
            .alert("新建相册", isPresented: $showNewAlbum) {
                TextField("相册名称", text: $newAlbumName)
                    .accessibilityIdentifier("album-name")
                Button("取消", role: .cancel) {
                    albumTargets = []
                    newAlbumName = ""
                }
                Button("创建") {
                    tryAction {
                        selectedAlbum = try store.createAlbum(newAlbumName, moving: albumTargets)
                        favoritesOnly = false
                        mediaFilter = nil
                        albumTargets = []
                        newAlbumName = ""
                        finishSelection()
                    }
                }
                .disabled(newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .alert("操作失败", isPresented: errorAlertBinding) {
                Button("好", role: .cancel) { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "未知错误")
            }
            .confirmationDialog("移到最近删除？", isPresented: $confirmBatchDelete, titleVisibility: .visible) {
                Button("移动 \(selectedIDs.count) 个项目", role: .destructive) {
                    tryAction { try store.moveToTrash(selectedIDs) }
                    finishSelection()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这些项目将在 30 天后自动永久删除。")
            }
            .confirmationDialog(
                "已安全导入 \(importedSystemAssetIDs.count) 个项目",
                isPresented: $confirmDeleteSystemOriginals,
                titleVisibility: .visible
            ) {
                Button("删除系统照片中的原件", role: .destructive) {
                    let identifiers = importedSystemAssetIDs
                    importedSystemAssetIDs = []
                    Task {
                        do {
                            try await store.deleteSystemAssets(localIdentifiers: identifiers)
                        } catch {
                            store.errorMessage = error.localizedDescription
                        }
                    }
                }
                Button("保留系统原件", role: .cancel) {
                    importedSystemAssetIDs = []
                }
            } message: {
                Text(importNote + "删除会影响启用 iCloud 照片的其他设备；项目仍可能保留在系统“最近删除”中。iOS 会处理权限和删除确认。")
            }
    }

    private var presentedNavigation: some View {
        navigationView
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    tryAction { try store.importCapturedImage(image, toAlbum: selectedAlbum) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showTrash) {
                RecentlyDeletedView()
            }
            .sheet(isPresented: $showManagement) {
                VaultManagementView()
            }
            .sheet(isPresented: $showAlbums) {
                VaultAlbumsView { album in
                    selectedAlbum = album
                    favoritesOnly = false
                    mediaFilter = nil
                    finishSelection()
                }
            }
    }

    private var navigationView: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                filterBar
                vaultContent
                if !isSelecting {
                    Text("\(visibleItems.count) 个项目 · 右滑可锁定退出")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(10)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
                guard path.isEmpty, value.translation.width > 100,
                      abs(value.translation.height) < value.translation.width / 2 else { return }
                onLock()
            })
            .accessibilityAction(.escape, onLock)
            .safeAreaInset(edge: .bottom) {
                if isSelecting { selectionBar }
            }
            .navigationTitle(selectedAlbum ?? (favoritesOnly ? "收藏" : "私人空间"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: VaultItem.self) { item in
                VaultDetailView(itemID: item.id, galleryIDs: visibleItems.map(\.id), onLock: onLock)
            }
            .toolbar { vaultToolbar }
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
            .onChange(of: pickerItems) { newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    let previousCount = store.activeItems.count
                    let identifiers = await store.importSelections(newItems, toAlbum: selectedAlbum)
                    pickerItems = []
                    guard store.isLoaded else { return }
                    favoritesOnly = false
                    mediaFilter = nil
                    if !identifiers.isEmpty {
                        importNote = store.errorMessage.map { $0 + "\n" } ?? ""
                        store.errorMessage = nil
                        importedSystemAssetIDs = identifiers
                        confirmDeleteSystemOriginals = true
                    } else if store.activeItems.count > previousCount,
                              store.errorMessage == nil {
                        store.errorMessage = "项目已安全导入，但系统没有提供可删除的原件标识，因此没有发起删除。请在系统“照片”中手动删除原件。"
                    }
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $pickerItems,
                maxSelectionCount: 50,
                matching: .any(of: [.images, .videos]),
                photoLibrary: .shared()
            )
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    selectedAlbum = nil
                    favoritesOnly = false
                    mediaFilter = nil
                    finishSelection()
                } label: {
                    Label("全部", systemImage: "square.grid.2x2")
                }
                Button { showAlbums = true } label: { Label("相册", systemImage: "folder") }
                    .accessibilityIdentifier("vault-albums")
                Button {
                    favoritesOnly.toggle()
                    finishSelection()
                } label: { Label("收藏", systemImage: favoritesOnly ? "heart.fill" : "heart") }
                    .tint(favoritesOnly ? .pink : .accentColor)
                    .accessibilityValue(favoritesOnly ? "已筛选" : "未筛选")
                Button {
                    mediaFilter = mediaFilter == .photo ? nil : .photo
                    finishSelection()
                } label: { Label("照片", systemImage: "photo") }
                    .accessibilityValue(mediaFilter == .photo ? "已筛选" : "未筛选")
                Button {
                    mediaFilter = mediaFilter == .video ? nil : .video
                    finishSelection()
                } label: { Label("视频", systemImage: "video") }
                    .accessibilityValue(mediaFilter == .video ? "已筛选" : "未筛选")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var vaultContent: some View {
        if visibleItems.isEmpty {
            VStack(spacing: 0) {
                EmptyStateView(
                    emptyTitle,
                    systemImage: favoritesOnly ? "heart" : "photo.on.rectangle.angled",
                    description: emptyDescription
                )
                Button(action: requestPhotoImport) {
                    Label("导入照片或视频", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(visibleItems) { item in gridItem(item) }
                }
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    @ViewBuilder
    private func gridItem(_ item: VaultItem) -> some View {
        if isSelecting {
            Button {
                if selectedIDs.contains(item.id) {
                    selectedIDs.remove(item.id)
                } else {
                    selectedIDs.insert(item.id)
                }
            } label: {
                VaultGridCell(item: item, isSelected: selectedIDs.contains(item.id))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: item) {
                VaultGridCell(item: item)
            }
            .accessibilityIdentifier("vault-media-link")
            .buttonStyle(.plain)
            .contextMenu { itemContextMenu(item) }
        }
    }

    @ViewBuilder
    private func itemContextMenu(_ item: VaultItem) -> some View {
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

    @ToolbarContentBuilder
    private var vaultToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if isSelecting {
                Button("取消") { finishSelection() }
            } else {
                Button(action: onLock) {
                    Label("锁定", systemImage: "lock")
                }
                .accessibilityIdentifier("vault-lock")
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isSelecting {
                Button(selectedIDs.count == visibleItems.count ? "取消全选" : "全选") {
                    selectedIDs = selectedIDs.count == visibleItems.count ? [] : Set(visibleItems.map(\.id))
                }
            } else {
                Button(action: requestPhotoImport) {
                    Label("导入照片或视频", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("vault-import")
                .disabled(store.isBusy)
                vaultMenu
            }
        }
    }

    private var vaultMenu: some View {
        Menu {
            Button {
                albumTargets = []
                showNewAlbum = true
            } label: {
                Label("新建相册", systemImage: "folder.badge.plus")
            }
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

            Menu("排序") {
                ForEach(VaultSortOrder.allCases) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        if sortOrder == order {
                            Label(order.rawValue, systemImage: "checkmark")
                        } else {
                            Text(order.rawValue)
                        }
                    }
                }
            }

            Divider()
            Button {
                isSelecting = true
            } label: {
                Label("选择项目", systemImage: "checkmark.circle")
            }
            .disabled(visibleItems.isEmpty)
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
            Label("更多", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("vault-more")
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
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
                albumTargets = [item.id]
                showNewAlbum = true
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

    private func requestPhotoImport() {
        showPhotoPicker = true
    }

    private var selectionBar: some View {
        selectionLayout {
            Text("已选 \(selectedIDs.count) 项")
                .font(.footnote.monospacedDigit())
            Button {
                tryAction { try store.setFavorite(selectedIDs, value: true) }
                finishSelection()
            } label: {
                Label("收藏", systemImage: "heart")
            }
            .disabled(selectedIDs.isEmpty)

            Menu {
                Button("不属于任何相册") {
                    tryAction { try store.assign(selectedIDs, toAlbum: nil) }
                    finishSelection()
                }
                ForEach(store.albums, id: \.self) { album in
                    Button(album) {
                        tryAction { try store.assign(selectedIDs, toAlbum: album) }
                        finishSelection()
                    }
                }
                Button("新建相册…") {
                    albumTargets = selectedIDs
                    showNewAlbum = true
                }
            } label: {
                Label("相册", systemImage: "folder")
            }
            .disabled(selectedIDs.isEmpty)

            Button(role: .destructive) {
                confirmBatchDelete = true
            } label: {
                Label("删除", systemImage: "trash")
            }
            .disabled(selectedIDs.isEmpty)
        }
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var selectionLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(alignment: .center, spacing: 12))
        }
        return AnyLayout(HStackLayout(alignment: .center, spacing: 28))
    }

    private func finishSelection() {
        selectedIDs = []
        isSelecting = false
    }
}

private struct VaultAlbumsView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var editingAlbum: String?
    @State private var name = ""
    @State private var deletingAlbum: String?
    @State private var errorMessage: String?
    let onSelect: (String?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                    dismiss()
                } label: { Label("全部照片与视频", systemImage: "square.grid.2x2") }
                Section("我的相册") {
                    if store.albums.isEmpty {
                        Text("先建一个相册，再把照片或视频导入其中。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.albums, id: \.self) { album in
                        Button {
                            onSelect(album)
                            dismiss()
                        } label: {
                            HStack {
                                Label(album, systemImage: "folder")
                                Spacer()
                                Text("\(store.activeItems.filter { $0.albumName == album }.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("删除相册", role: .destructive) { deletingAlbum = album }
                            Button("重命名") { editingAlbum = album; name = album; showEditor = true }
                                .tint(.blue)
                        }
                        .contextMenu {
                            Button("重命名") { editingAlbum = album; name = album; showEditor = true }
                            Button("删除相册", role: .destructive) { deletingAlbum = album }
                        }
                    }
                }
                Button {
                    editingAlbum = nil
                    name = ""
                    showEditor = true
                } label: { Label("新建相册", systemImage: "folder.badge.plus") }
                .accessibilityIdentifier("albums-create")
            }
            .navigationTitle("相册")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .alert(editingAlbum == nil ? "新建相册" : "重命名相册", isPresented: $showEditor) {
                TextField("相册名称", text: $name).accessibilityIdentifier("album-name")
                Button("取消", role: .cancel) {}
                Button("保存") {
                    perform {
                        if let editingAlbum { try store.renameAlbum(editingAlbum, to: name) }
                        else { try store.createAlbum(name) }
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .confirmationDialog("删除相册？", isPresented: Binding(
                get: { deletingAlbum != nil }, set: { if !$0 { deletingAlbum = nil } }
            ), titleVisibility: .visible) {
                Button("仅删除相册，保留项目", role: .destructive) {
                    if let album = deletingAlbum { perform { try store.deleteAlbum(album) } }
                    deletingAlbum = nil
                }
                Button("取消", role: .cancel) { deletingAlbum = nil }
            } message: {
                Text("照片和视频会保留在“全部项目”中，不会被删除。")
            }
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("好", role: .cancel) { errorMessage = nil } }
            message: { Text(errorMessage ?? "") }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
    }
}

private struct VaultGridCell: View {
    @EnvironmentObject private var store: VaultStore
    let item: VaultItem
    var isSelected = false
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

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .task(id: item.id) {
            if let data = try? store.thumbnailData(for: item) {
                image = UIImage(data: data)
            }
        }
        .accessibilityLabel(item.mediaKind == .photo ? "照片" : "视频")
        .accessibilityValue(item.importedAt.formatted(date: .abbreviated, time: .shortened))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct VaultDetailView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var itemID: UUID
    let galleryIDs: [UUID]
    let onLock: () -> Void
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var confirmExport = false
    @State private var confirmDelete = false
    @State private var loadError: String?

    init(itemID: UUID, galleryIDs: [UUID], onLock: @escaping () -> Void) {
        _itemID = State(initialValue: itemID)
        self.galleryIDs = galleryIDs
        self.onLock = onLock
    }

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
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button { browse(-1) } label: { Label("上一项", systemImage: "chevron.left") }
                            .disabled((galleryIDs.firstIndex(of: itemID) ?? 0) == 0)
                        Spacer()
                        Text("\((galleryIDs.firstIndex(of: itemID) ?? 0) + 1) / \(galleryIDs.count)")
                            .font(.footnote.monospacedDigit())
                        Spacer()
                        Button { browse(1) } label: { Label("下一项", systemImage: "chevron.right") }
                            .disabled((galleryIDs.firstIndex(of: itemID) ?? 0) >= galleryIDs.count - 1)
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(action: onLock) {
                            Label("锁定退出", systemImage: "lock.fill").labelStyle(.iconOnly)
                        }
                        Button {
                            confirmExport = true
                        } label: {
                            Label("导出", systemImage: "square.and.arrow.up")
                                .labelStyle(.iconOnly)
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
                            Label("更多", systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                .task(id: item.id) { load(item) }
            } else {
                EmptyStateView("项目不存在", systemImage: "exclamationmark.triangle")
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ShareSheet(items: [exportURL]) {
                    if item?.mediaKind == .photo { store.cleanupTemporaryExports() }
                }
            }
        }
        .confirmationDialog("导出会产生新的可见副本", isPresented: $confirmExport, titleVisibility: .visible) {
            Button("继续导出") {
                guard let item else { return }
                prepareShare(item)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("保存到系统“照片”会重新公开显示；通过文件或其他 App 分享也会在目标位置留下副本。")
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
        .onDisappear {
            player?.pause()
            store.cleanupTemporaryExports()
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

    private func browse(_ offset: Int) {
        guard let current = galleryIDs.firstIndex(of: itemID), galleryIDs.indices.contains(current + offset) else { return }
        player?.pause()
        player = nil
        image = nil
        store.cleanupTemporaryExports()
        itemID = galleryIDs[current + offset]
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

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "私人照片"
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.imageView = imageView
        context.coordinator.reduceMotion = reduceMotion
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        context.coordinator.reduceMotion = reduceMotion
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        var reduceMotion = false

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func didDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView,
                  let imageView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: !reduceMotion)
                return
            }

            let targetScale = min(2, scrollView.maximumZoomScale)
            let point = recognizer.location(in: imageView)
            let size = CGSize(
                width: scrollView.bounds.width / targetScale,
                height: scrollView.bounds.height / targetScale
            )
            let rect = CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            )
            scrollView.zoom(to: rect, animated: !reduceMotion)
        }
    }
}

private struct RecentlyDeletedView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEmpty = false
    @State private var itemToDeletePermanently: VaultItem?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if store.deletedItems.isEmpty {
                    EmptyStateView("最近删除为空", systemImage: "trash")
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
                                Button("恢复") { perform { try store.restore(item) } }
                                Button("永久删除", role: .destructive) {
                                    itemToDeletePermanently = item
                                }
                            } label: {
                                Label("更多操作", systemImage: "ellipsis.circle")
                                    .labelStyle(.iconOnly)
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu("批量操作") {
                            Button("全部恢复") { perform { try store.restoreAllTrash() } }
                            Button("全部删除", role: .destructive) { confirmEmpty = true }
                        }
                    }
                }
            }
            .confirmationDialog("永久删除全部项目？", isPresented: $confirmEmpty, titleVisibility: .visible) {
                Button("永久删除", role: .destructive) { perform { try store.emptyTrash() } }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作无法撤销。")
            }
            .confirmationDialog(
                "永久删除此项目？",
                isPresented: Binding(
                    get: { itemToDeletePermanently != nil },
                    set: { if !$0 { itemToDeletePermanently = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("永久删除", role: .destructive) {
                    guard let item = itemToDeletePermanently else { return }
                    itemToDeletePermanently = nil
                    perform { try store.deletePermanently(item) }
                }
                Button("取消", role: .cancel) { itemToDeletePermanently = nil }
            } message: {
                Text("此操作无法撤销。")
            }
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
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
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("再次输入", text: $confirmation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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
                ShareSheet(items: [backupURL]) {
                    store.cleanupTemporaryExports()
                }
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
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                Button("验证并恢复") { restore() }
                    .disabled(selectedURL == nil || password.isEmpty)
            } footer: {
                Text("恢复会合并备份内容和相册；同一项目保留当前版本，不覆盖现有照片或视频。")
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

    private var trimmedHint: String {
        hint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canChange: Bool {
        !current.isEmpty
            && VaultAuthStore.isValidPasscode(new)
            && new == confirmation
            && (trimmedHint.isEmpty || !trimmedHint.localizedCaseInsensitiveContains(new))
    }

    var body: some View {
        Form {
            Section {
                SecureField("当前口令", text: $current)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("新口令", text: $new)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("再次输入新口令", text: $confirmation)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("新提示词（可选）", text: $hint)
                if !new.isEmpty && !VaultAuthStore.isValidPasscode(new) {
                    validationLabel("新口令至少需要 6 位数字。")
                } else if !confirmation.isEmpty && new != confirmation {
                    validationLabel("两次输入的新口令不一致。")
                } else if !new.isEmpty
                            && !trimmedHint.isEmpty
                            && trimmedHint.localizedCaseInsensitiveContains(new) {
                    validationLabel("提示词不能包含完整口令。")
                }
            }
            Button("修改口令") { change() }
                .disabled(!canChange)
        }
        .navigationTitle("修改口令")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if hint.isEmpty { hint = authStore.hint }
        }
        .alert("修改口令", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func validationLabel(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
    }

    private func change() {
        do {
            try authStore.changePasscode(
                current: current,
                new: new,
                confirmation: confirmation,
                hint: trimmedHint
            )
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
    var onComplete: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { onComplete() }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
