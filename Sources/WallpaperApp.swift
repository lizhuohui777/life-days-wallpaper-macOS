import AppKit
import ImageIO
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let picker = NSDatePicker()
    let imageStatus = NSTextField(labelWithString: "当前背景：自带照片")
    let cleanupCheckbox = NSButton(checkboxWithTitle: "清理本程序旧墙纸记录（兼容模式，会刷新墙纸服务）", target: nil, action: nil)
    var selectedImageData: Data?
    var useCustomBackground = false
    var backgroundRevision = "default"
    let playerNameField = NSTextField(string: "玩家")
    let status = NSTextField(wrappingLabelWithString: "选择起始日期；起始当天算第 1 天。")
    let count = NSTextField(labelWithString: "")
    let button = NSButton(title: "应用并开启每日更新", target: nil, action: nil)
    let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/DayWallpaper")
    var agent: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/local.daywallpaper.plist") }
    let formatter: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 610), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "人生天数壁纸"
        window.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.925, blue: 0.895, alpha: 1)
        let content = window.contentView!
        let title = NSTextField(labelWithString: "让每一天，有迹可循。")
        title.font = .systemFont(ofSize: 27, weight: .medium)
        title.frame = NSRect(x: 40, y: 530, width: 460, height: 40)
        content.addSubview(title)
        let label = NSTextField(labelWithString: "起始日期")
        label.frame = NSRect(x: 40, y: 477, width: 100, height: 25)
        content.addSubview(label)
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay]
        picker.maxDate = Date()
        picker.frame = NSRect(x: 150, y: 473, width: 235, height: 30)
        picker.target = self; picker.action = #selector(dateChanged)
        var saved = formatter.string(from: Date())
        if let data = try? Data(contentsOf: root.appendingPathComponent("settings.plist")), let settings = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] { saved = settings["startDate"] ?? saved; playerNameField.stringValue = settings["playerName"] ?? "玩家"
            useCustomBackground = settings["backgroundMode"] == "custom" && FileManager.default.fileExists(atPath: root.appendingPathComponent("custom-background.jpg").path)
            backgroundRevision = settings["backgroundRevision"] ?? "default"
            cleanupCheckbox.state = settings["cleanupLegacy"] == "true" ? .on : .off
        }
        picker.dateValue = formatter.date(from: saved) ?? Date()
        content.addSubview(picker)
        let nameLabel = NSTextField(labelWithString: "玩家名字")
        nameLabel.frame = NSRect(x: 40, y: 407, width: 100, height: 25)
        content.addSubview(nameLabel)
        playerNameField.placeholderString = "填写玩家名字（最多 20 个字符）"
        playerNameField.font = .systemFont(ofSize: 16)
        playerNameField.frame = NSRect(x: 150, y: 403, width: 310, height: 30)
        content.addSubview(playerNameField)
        let imageButton = NSButton(title: "选择背景图片…", target: self, action: #selector(selectBackground))
        imageButton.bezelStyle = .rounded
        imageButton.frame = NSRect(x: 35, y: 335, width: 190, height: 34)
        content.addSubview(imageButton)
        let resetButton = NSButton(title: "恢复自带照片", target: self, action: #selector(resetBackground))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 230, y: 335, width: 170, height: 34)
        content.addSubview(resetButton)
        imageStatus.frame = NSRect(x: 40, y: 300, width: 460, height: 25)
        imageStatus.stringValue = useCustomBackground ? "当前背景：自选图片（仅保存到本机）" : "当前背景：自带照片"
        content.addSubview(imageStatus)
        cleanupCheckbox.frame = NSRect(x: 40, y: 250, width: 470, height: 30)
        content.addSubview(cleanupCheckbox)
        count.font = .systemFont(ofSize: 22, weight: .light)
        count.frame = NSRect(x: 40, y: 200, width: 460, height: 35)
        content.addSubview(count)
        button.target = self; button.action = #selector(install)
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 35, y: 132, width: 260, height: 42)
        content.addSubview(button)
        status.font = .systemFont(ofSize: 13)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 40, y: 40, width: 460, height: 76)
        content.addSubview(status)
        dateChanged()
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func selectBackground() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] result in
            guard let self = self, result == .OK, let url = panel.url else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                self.selectedImageData = try ImageImport.normalizedImage(at: url)
                self.useCustomBackground = true
                self.backgroundRevision = UUID().uuidString
                self.imageStatus.stringValue = "已选择：\(url.lastPathComponent)；点击应用后生效"
                self.status.stringValue = "图片仅保存到本机，不会上传。"
            } catch { self.status.stringValue = error.localizedDescription }
        }
    }
    @objc func resetBackground() {
        selectedImageData = nil
        useCustomBackground = false
        backgroundRevision = "default"
        imageStatus.stringValue = "当前背景：自带照片；点击应用后生效"
    }
    @objc func dateChanged() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let days = LifeDays.count(start: picker.dateValue, today: Date(), calendar: cal)
        count.stringValue = "今天是第 \(days.formatted()) 天"
    }
    func run(_ path: String, _ args: [String]) throws {
        let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        let log = root.appendingPathComponent("installation.log")
        if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: log); defer { try? handle.close() }
        try handle.seekToEnd(); p.standardOutput = handle; p.standardError = handle
        try p.run(); p.waitUntilExit()
        if p.terminationStatus != 0 { throw NSError(domain: "DayWallpaper", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "操作失败（\(p.terminationStatus)）。请查看 ~/Library/Application Support/DayWallpaper/installation.log；如提示自动化权限，请在系统设置 → 隐私与安全性 → 自动化中允许控制 System Events，再重新点击应用。"] ) }
    }
    @objc func install() {
        let playerName = playerNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !playerName.isEmpty, playerName.count <= 20, playerName.rangeOfCharacter(from: .controlCharacters) == nil else {
            status.stringValue = "请填写 1–20 个字符的玩家名字。"
            window.makeFirstResponder(playerNameField)
            return
        }
        playerNameField.stringValue = playerName
        button.isEnabled = false
        defer { button.isEnabled = true }
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            guard (try root.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else { throw NSError(domain: "DayWallpaper", code: 6, userInfo: [NSLocalizedDescriptionKey: "配置目录不能是符号链接。"]) }
            try fm.createDirectory(at: agent.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard let worker = Bundle.main.url(forResource: "day-wallpaper", withExtension: nil) else { throw NSError(domain: "DayWallpaper", code: 1, userInfo: [NSLocalizedDescriptionKey: "安装包缺少壁纸工具，请重新下载安装包。"]) }
            guard let background = Bundle.main.url(forResource: "background", withExtension: "jpg") else { throw NSError(domain: "DayWallpaper", code: 2, userInfo: [NSLocalizedDescriptionKey: "安装包缺少背景图片。请重新下载安装包。"]) }
            try Data(contentsOf: background).write(to: root.appendingPathComponent("background.jpg"), options: .atomic)
            if let data = selectedImageData { try data.write(to: root.appendingPathComponent("custom-background.jpg"), options: .atomic) }
            let uid = String(getuid())
            try? run("/bin/launchctl", ["bootout", "gui/" + uid, agent.path])
            let destination = root.appendingPathComponent("day-wallpaper")
            let staged = root.appendingPathComponent("day-wallpaper-new")
            try? fm.removeItem(at: staged)
            try fm.copyItem(at: worker, to: staged)
            if fm.fileExists(atPath: destination.path) { _ = try fm.replaceItemAt(destination, withItemAt: staged) }
            else { try fm.moveItem(at: staged, to: destination) }
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            let settings = ["startDate": formatter.string(from: picker.dateValue), "playerName": playerName, "backgroundMode": useCustomBackground ? "custom" : "default", "backgroundRevision": backgroundRevision, "cleanupLegacy": cleanupCheckbox.state == .on ? "true" : "false"]
            try PropertyListSerialization.data(fromPropertyList: settings, format: .xml, options: 0).write(to: root.appendingPathComponent("settings.plist"), options: .atomic)
            let plist = WallpaperSchedule.launchAgent(worker: destination, root: root)
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: agent, options: .atomic)
            try run("/bin/launchctl", ["bootstrap", "gui/" + uid, agent.path])
            try run(destination.path, [])
            selectedImageData = nil
            imageStatus.stringValue = useCustomBackground ? "当前背景：自选图片（仅保存到本机）" : "当前背景：自带照片"
            status.stringValue = "已应用：每天午夜更新，登录时检查；午夜休眠时在唤醒后补更。失败后自动重试。可以退出应用，再次打开可修改设置。"
        } catch { status.stringValue = error.localizedDescription }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
