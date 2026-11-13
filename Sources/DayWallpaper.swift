import AppKit
import CoreText
import Darwin

func runWorker() throws {
let fm = FileManager.default
let preview = CommandLine.arguments.contains("--preview")
let previewRoot = ProcessInfo.processInfo.environment["DAYWALLPAPER_PREVIEW_ROOT"] ?? "/private/tmp/day-wallpaper-preview"
let root = preview ? URL(fileURLWithPath: previewRoot) : fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/DayWallpaper")
try fm.createDirectory(at: root, withIntermediateDirectories: true)
if (try root.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true { fputs("配置目录不能是符号链接\n", stderr); exit(1) }
// Serialize launchd and manual runs so a successful update cannot race another writer.
let lockFD = open(root.appendingPathComponent("update.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
guard lockFD >= 0 else { throw NSError(domain: "DayWallpaper", code: 10, userInfo: [NSLocalizedDescriptionKey: "无法创建壁纸更新锁。允许下一次任务重试。"]) }
guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { close(lockFD); exit(0) }
defer { flock(lockFD, LOCK_UN); close(lockFD) }
// Migrate only wallpaper references owned by this app; preserve other pictures and screen savers.
func cleanSystemWallpaperReferences(root: URL, output: URL) throws {
    let store = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    guard fm.fileExists(atPath: store.path) else { return }
    for attempt in 0..<5 {
    let original = try Data(contentsOf: store)
    guard let updated = try migrateWallpaperStore(original, root: root, output: output) else { return }
    let backup = root.appendingPathComponent("wallpaper-store-before-cleanup.plist")
    if !fm.fileExists(atPath: backup.path) { try original.write(to: backup, options: .atomic) }
    guard try Data(contentsOf: store) == original else {
        if attempt < 4 { RunLoop.current.run(until: Date().addingTimeInterval(0.3)); continue }
        throw NSError(domain: "DayWallpaper", code: 4, userInfo: [NSLocalizedDescriptionKey: "墙纸设置正在变化，下一次检查时重试清理。"])
    }
    try updated.write(to: store, options: .atomic)
    let refresh = Process()
    refresh.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
    refresh.arguments = ["WallpaperAgent"]
    try refresh.run()
    refresh.waitUntilExit()
    return
    }
}

// Read all system references before deleting only this app's obsolete generated files.
func pruneUnusedImages(output: URL, cleanupLegacy: Bool) throws {
    let store = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    if let data = try? Data(contentsOf: store), let references = try? WallpaperUpdate.referencedFiles(in: data, root: root) {
        let previous = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter {
            WallpaperUpdate.ownsFilename($0.lastPathComponent) && $0 != output && !references.contains($0.lastPathComponent)
        }
        try WallpaperUpdate.removeObsoleteImages(root: root, current: output, references: references)
        if cleanupLegacy {
            let legacy = root.appendingPathComponent("wallpaper.png")
            let retired = previous + (legacy != output && !references.contains(legacy.lastPathComponent) ? [legacy] : [])
            let cache = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/com.apple.wallpaper.agent/Data/Library/Caches/com.apple.wallpaper.caches/extension-com.apple.wallpaper.extension.image")
            do { try WallpaperUpdate.removeRetiredRenderCaches(cacheRoot: cache, retired: retired, current: output) }
            catch { fputs("旧壁纸已清理；系统渲染缓存暂不可清理：\(error.localizedDescription)\n", stderr) }
        }
    }
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = .current
let configURL = root.appendingPathComponent("settings.plist")
let config = (try? Data(contentsOf: configURL)).flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: String]
let backgroundRevision = config?["backgroundRevision"] ?? "default"
let cleanupLegacy = config?["cleanupLegacy"] == "true"
let formatterStart = DateFormatter()
formatterStart.locale = Locale(identifier: "en_US_POSIX")
formatterStart.dateFormat = "yyyy-MM-dd"
let startString = config?["startDate"] ?? formatterStart.string(from: Date())
let savedName = (config?["playerName"] ?? "玩家").trimmingCharacters(in: .whitespacesAndNewlines)
let playerName = savedName.isEmpty ? "玩家" : String(savedName.prefix(20))
let parts = startString.split(separator: "-").compactMap { Int($0) }
guard parts.count == 3, let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { exit(1) }
let previewDate = preview ? ProcessInfo.processInfo.environment["DAYWALLPAPER_PREVIEW_DATE"] : nil
let previewFormatter = DateFormatter()
previewFormatter.locale = Locale(identifier: "en_US_POSIX")
previewFormatter.dateFormat = "yyyy-MM-dd"
let today = calendar.startOfDay(for: previewDate.flatMap { previewFormatter.date(from: $0) } ?? Date())
let days = LifeDays.count(start: start, today: today, calendar: calendar)
let formatter = DateFormatter()
formatter.locale = Locale(identifier: "en_US_POSIX")
formatter.timeZone = calendar.timeZone
formatter.dateFormat = "yyyy-MM-dd"
let stamp = formatter.string(from: today)
let marker = root.appendingPathComponent("last-date.txt")
let revisionKey = stamp + "-v15-owned-cleanup-" + startString + "-" + playerName + "-" + backgroundRevision
let output = WallpaperUpdate.outputURL(root: root, key: revisionKey)
let workspace = NSWorkspace.shared
let screens = preview ? [] : NSScreen.screens
if !preview && screens.isEmpty { throw NSError(domain: "DayWallpaper", code: 11, userInfo: [NSLocalizedDescriptionKey: "当前没有可用屏幕，登录或唤醒后重试。"]) }
let currentURLs = screens.map { workspace.desktopImageURL(for: $0) }
if !preview, (try? String(contentsOf: marker, encoding: .utf8)) == revisionKey,
   fm.fileExists(atPath: output.path), !WallpaperUpdate.needsApplication(expected: output, actual: currentURLs) {
    if cleanupLegacy { try cleanSystemWallpaperReferences(root: root, output: output) }
    try pruneUnusedImages(output: output, cleanupLegacy: cleanupLegacy)
    exit(0)
}
if preview || !fm.fileExists(atPath: output.path) {
let width = 3024, height = 1964
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.deletingLastPathComponent()
let custom = config?["backgroundMode"] == "custom" ? [root.appendingPathComponent("custom-background.jpg")] : []
let candidates = custom + [executable.appendingPathComponent("background.jpg"), URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Resources/background.jpg")]
guard let background = candidates.compactMap({ NSImage(contentsOf: $0) }).first else {
    fputs("缺少背景图片 background.jpg\n", stderr); exit(1)
}
let scale = max(CGFloat(width) / background.size.width, CGFloat(height) / background.size.height)
let photoSize = NSSize(width: background.size.width * scale, height: background.size.height * scale)
background.draw(in: NSRect(x: (CGFloat(width) - photoSize.width) / 2, y: (CGFloat(height) - photoSize.height) / 2, width: photoSize.width, height: photoSize.height), from: .zero, operation: .copy, fraction: 1)
guard let greetingFont = NSFont(name: "STSongti-SC-Black", size: 48),
      let numberFont = NSFont(name: "Georgia-Bold", size: 250),
      let daysFont = NSFont(name: "Georgia-Bold", size: 160) else {
    fputs("壁纸字体不可用\n", stderr); exit(1)
}
func line(_ text: String, font: NSFont, tracking: CGFloat) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white, .kern: tracking]))
}
let titleLine = line("玩家\(playerName)：", font: greetingFont, tracking: 3)
let numberLine = line(days.formatted(), font: numberFont, tracking: -10)
let daysLine = line("Days", font: daysFont, tracking: -4)
let wishLine = line("祝一切顺利！", font: greetingFont, tracking: 3)
func inkBounds(_ line: CTLine) -> CGRect { CTLineGetBoundsWithOptions(line, .useGlyphPathBounds) }
let numberBounds = inkBounds(numberLine)
let daysOffset = numberBounds.width + 48
let placements: [(CTLine, CGFloat, CGFloat)] = [(titleLine, 0, 420), (numberLine, 0, 140), (daysLine, daysOffset, 140), (wishLine, 0, 20)]
var contentBounds = CGRect.null
for (line, x, baseline) in placements {
    let bounds = inkBounds(line)
    contentBounds = contentBounds.union(CGRect(x: x, y: baseline + bounds.minY, width: bounds.width, height: bounds.height))
}
// Fit the entire group into the top-left cell of a 3 × 3 grid.
// Align visible glyph edges, so both Chinese lines start at the digit's edge.
let cellWidth = CGFloat(width) / 3
let cellHeight = CGFloat(height) / 3
let leftInset: CGFloat = 180
let topInset: CGFloat = 170
let rightInset: CGFloat = 40
let bottomInset: CGFloat = 40
let layoutScale = min(1, (cellWidth - leftInset - rightInset) / contentBounds.width, (cellHeight - topInset - bottomInset) / contentBounds.height)
let context = NSGraphicsContext.current!.cgContext
context.saveGState()
context.translateBy(x: leftInset, y: CGFloat(height) - topInset - contentBounds.maxY * layoutScale)
context.scaleBy(x: layoutScale, y: layoutScale)
context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor.black.withAlphaComponent(0.30).cgColor)
for (line, x, baseline) in placements {
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: x - inkBounds(line).minX, y: baseline)
    CTLineDraw(line, context)
}
context.restoreGState()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output, options: .atomic)
}
if preview { print(output.path); exit(0) }
// Give each rendered revision a new URL; replacing bytes at wallpaper.png leaves stale macOS caches.
for screen in screens {
    let options = workspace.desktopImageOptions(for: screen) ?? [:]
    try workspace.setDesktopImageURL(output, for: screen, options: options)
}
let escaped = output.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
let script = NSAppleScript(source: """
tell application "System Events"
    repeat with desktopItem in desktops
        try
            set picture rotation of desktopItem to 0
        end try
        try
            set random order of desktopItem to false
        end try
        set picture of desktopItem to "\(escaped)"
    end repeat
end tell
""")!
var error: NSDictionary?
script.executeAndReturnError(&error)
if error != nil { fputs("部分桌面空间未能通过 System Events 更新；已使用公开接口更新当前屏幕。\n", stderr) }
var applied = false
for _ in 0..<10 {
    if !WallpaperUpdate.needsApplication(expected: output, actual: NSScreen.screens.map { workspace.desktopImageURL(for: $0) }) { applied = true; break }
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}
guard applied else { throw NSError(domain: "DayWallpaper", code: 12, userInfo: [NSLocalizedDescriptionKey: "系统尚未确认壁纸更新，将在下一次检查时重试。成功日期未写入。"]) }
if cleanupLegacy { try cleanSystemWallpaperReferences(root: root, output: output) }
// Application has been verified; now prune obsolete images.
try pruneUnusedImages(output: output, cleanupLegacy: cleanupLegacy)
try revisionKey.write(to: marker, atomically: true, encoding: .utf8)
let message = "\(ISO8601DateFormatter().string(from: Date())) applied days=\(days) screens=\(screens.count) file=\(output.lastPathComponent)\n"
let log = root.appendingPathComponent("update.log")
if !fm.fileExists(atPath: log.path) { fm.createFile(atPath: log.path, contents: nil) }
let handle = try FileHandle(forWritingTo: log)
try handle.seekToEnd(); try handle.write(contentsOf: Data(message.utf8)); try handle.close()

}
do { try runWorker() }
catch { fputs("壁纸更新失败：\(error.localizedDescription)\n", stderr); exit(1) }
