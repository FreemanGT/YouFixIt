import AppKit
import Foundation

/// Measures the disk side: caches that tools refill, leftovers of removed apps, old installers, simulator runtimes.
/// Slow (du) and rare (every six hours, or when the popover opens and the last look is over an hour old). Off the main actor.
enum DiskScanner {
    nonisolated static let home = NSHomeDirectory()

    struct Candidate: Sendable {
        let kind: DiskScan.Kind
        let path: String
        let name: String
        var modified: Date? = nil
    }

    /// Fixed, well-known places only. Never anything the user picked, never a symlink.
    nonisolated static func candidates() -> [Candidate] {
        var out: [Candidate] = [
            Candidate(kind: .derivedData, path: "\(home)/Library/Developer/Xcode/DerivedData", name: "Xcode build cache"),
            Candidate(kind: .deviceSupport, path: "\(home)/Library/Developer/Xcode/iOS DeviceSupport", name: "iPhone support files"),
            Candidate(kind: .devCache, path: "\(home)/.npm/_cacache", name: "npm download cache"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/pnpm", name: "pnpm cache"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/Yarn", name: "Yarn cache"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/pip", name: "pip cache"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/Homebrew", name: "Homebrew downloads"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/ms-playwright", name: "Playwright browsers"),
            Candidate(kind: .trash, path: "\(home)/.Trash", name: "Trash"),
        ]
        let fm = FileManager.default
        // Each tool keeps its own folder under ~/.cache; they are all refillable.
        if let names = try? fm.contentsOfDirectory(atPath: "\(home)/.cache") {
            for name in names where !name.hasPrefix(".") {
                out.append(Candidate(kind: .devCache, path: "\(home)/.cache/\(name)", name: "\(name) cache"))
            }
        }
        // Caches whose app is gone. Bundle-id-shaped folders only, never Apple's own, never a helper of an installed app
        // (com.example.app.ShipIt belongs to com.example.app), and only once nothing has touched them for a month.
        if let names = try? fm.contentsOfDirectory(atPath: "\(home)/Library/Caches") {
            for name in names where name.components(separatedBy: ".").count >= 3 && !name.hasPrefix("com.apple.") {
                var parts = name.components(separatedBy: ".")
                var owned = false
                while parts.count >= 2 {
                    if NSWorkspace.shared.urlForApplication(withBundleIdentifier: parts.joined(separator: ".")) != nil { owned = true; break }
                    parts.removeLast()
                }
                guard !owned else { continue }
                let path = "\(home)/Library/Caches/\(name)"
                let modified = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
                guard let modified, Date().timeIntervalSince(modified) >= 30 * 86_400 else { continue }
                out.append(Candidate(kind: .orphanCache, path: path, name: name, modified: modified))
            }
        }
        // Installers that have sat in Downloads for a month.
        let downloads = "\(home)/Downloads"
        if let names = try? fm.contentsOfDirectory(atPath: downloads) {
            for name in names where name.hasSuffix(".dmg") || name.hasSuffix(".pkg") {
                let path = "\(downloads)/\(name)"
                let modified = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
                if let modified, Date().timeIntervalSince(modified) >= 30 * 86_400 {
                    out.append(Candidate(kind: .installer, path: path, name: name, modified: modified))
                }
            }
        }
        return out.filter { c in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: c.path, isDirectory: &isDir) else { return false }
            let isLink = (try? fm.destinationOfSymbolicLink(atPath: c.path)) != nil
            return !isLink
        }
    }

    static func scan() async -> DiskScan {
        let list = candidates()
        var items: [DiskScan.Item] = []
        // du in small parallel batches; one slow tree must not hold the rest.
        await withTaskGroup(of: DiskScan.Item?.self) { group in
            var pending = list[...]
            var running = 0
            func launch(_ c: Candidate) {
                group.addTask {
                    guard let r = await Shell.run("/usr/bin/du", ["-sk", c.path], timeout: 60), r.status == 0,
                          let kb = UInt64(r.out.split(separator: "\t").first?.trimmingCharacters(in: .whitespaces) ?? "") else { return nil }
                    return DiskScan.Item(kind: c.kind, path: c.path, name: c.name, bytes: kb << 10, modified: c.modified)
                }
            }
            while running < 4, let c = pending.popFirst() { launch(c); running += 1 }
            for await item in group {
                if let item { items.append(item) }
                if let c = pending.popFirst() { launch(c) }
            }
        }
        let sims = await simulators()
        items += sims.items
        let values = try? URL(fileURLWithPath: home).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        return DiskScan(at: Date(), items: items.sorted { $0.bytes > $1.bytes }, unavailableSims: sims.unavailable,
                        freeBytes: UInt64(values?.volumeAvailableCapacityForImportantUsage ?? 0),
                        totalBytes: UInt64(values?.volumeTotalCapacity ?? 0))
    }

    /// Runtimes unused for two months (except the newest per platform) and devices unused for three, explained only.
    private static func simulators() async -> (items: [DiskScan.Item], unavailable: Int) {
        guard FileManager.default.fileExists(atPath: "/Applications/Xcode.app") else { return ([], 0) }
        var items: [DiskScan.Item] = []
        let iso = ISO8601DateFormatter()
        let now = Date()
        if let r = await Shell.run("/usr/bin/xcrun", ["simctl", "runtime", "list", "-j"], timeout: 30), r.status == 0,
           let data = r.out.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            var newest: [String: String] = [:]
            for (_, rt) in json {
                let platform = rt["platformIdentifier"] as? String ?? ""
                let version = rt["version"] as? String ?? ""
                if version.compare(newest[platform] ?? "", options: .numeric) == .orderedDescending { newest[platform] = version }
            }
            for (id, rt) in json {
                let platform = rt["platformIdentifier"] as? String ?? ""
                let version = rt["version"] as? String ?? ""
                let used = (rt["lastUsedAt"] as? String).flatMap { iso.date(from: $0) }
                let bytes = UInt64(rt["sizeBytes"] as? Double ?? 0)
                guard version != newest[platform], bytes > 0, now.timeIntervalSince(used ?? .distantPast) >= 60 * 86_400 else { continue }
                let name = "\(platform.components(separatedBy: ".").last?.replacingOccurrences(of: "simulator", with: "") ?? "") \(version)"
                items.append(DiskScan.Item(kind: .runtime, path: id, name: name.trimmingCharacters(in: .whitespaces), bytes: bytes, modified: used))
            }
        }
        var unavailable = 0
        if let r = await Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "-j"], timeout: 30), r.status == 0,
           let data = r.out.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let devices = json["devices"] as? [String: [[String: Any]]] {
            for (_, list) in devices {
                for d in list {
                    if (d["isAvailable"] as? Bool) == false { unavailable += 1; continue }
                    let used = (d["lastUsedAt"] as? String).flatMap { iso.date(from: $0) }
                    let bytes = UInt64(d["dataPathSize"] as? Double ?? 0)
                    guard bytes >= 1 << 30, now.timeIntervalSince(used ?? .distantPast) >= 90 * 86_400, let udid = d["udid"] as? String else { continue }
                    items.append(DiskScan.Item(kind: .oldDevice, path: udid, name: d["name"] as? String ?? "iPhone", bytes: bytes, modified: used))
                }
            }
        }
        return (items, unavailable)
    }
}
