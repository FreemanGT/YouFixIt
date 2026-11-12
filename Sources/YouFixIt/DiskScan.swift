import AppKit
import Foundation

/// Measures the disk side: caches that tools refill, leftovers of removed apps, old installers, simulator runtimes.
/// Slow (du) and rare (every six hours, or when the popover opens and the last look is over an hour old). Off the main actor.
enum DiskScanner {
    nonisolated static let home = NSHomeDirectory()
    /// Folders under ~/.cache that are plain download caches, refilled by their tool on the next run.
    /// Anything else there (browser installs, model files, a running tool's own data) is explained, never trashed.
    nonisolated static let refillable: Set<String> = ["pip", "uv", "pypoetry", "pnpm", "yarn", "node-gyp", "typescript", "go-build", "prisma", "pre-commit"]

    struct Candidate: Sendable {
        let kind: DiskScan.Kind
        let path: String
        let name: String
        var modified: Date? = nil
        var owner: String? = nil
    }

    /// Working directories and command lines of every process of ours, read once per look.
    typealias Usage = (cwds: [String], args: [String])

    /// Something of ours runs inside the folder, or names a file in it on its command line.
    nonisolated static func inUse(_ path: String, by usage: Usage) -> Bool {
        let inside = path + "/"
        return usage.cwds.contains { $0 == path || $0.hasPrefix(inside) } || usage.args.contains { $0.contains(inside) || $0.hasSuffix(path) }
    }

    /// Fixed, well-known places only. Never anything the user picked, never a symlink.
    nonisolated static func candidates(using usage: Usage = ([], [])) -> [Candidate] {
        var out: [Candidate] = [
            Candidate(kind: .derivedData, path: "\(home)/Library/Developer/Xcode/DerivedData", name: "Xcode build cache"),
            Candidate(kind: .deviceSupport, path: "\(home)/Library/Developer/Xcode/iOS DeviceSupport", name: "iPhone support files"),
            Candidate(kind: .previews, path: "\(home)/Library/Developer/Xcode/UserData/Previews", name: "Xcode preview cache"),
            Candidate(kind: .simCache, path: "\(home)/Library/Developer/CoreSimulator/Caches", name: "Simulator cache"),
            Candidate(kind: .devCache, path: "\(home)/.npm/_cacache", name: "npm download cache"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/pnpm", name: "pnpm cache"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/Yarn", name: "Yarn cache"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/pip", name: "pip cache"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/Homebrew", name: "Homebrew downloads"),
            Candidate(kind: .devCache, path: "\(home)/Library/Caches/CocoaPods", name: "CocoaPods cache"),
            Candidate(kind: .devCache, path: "\(home)/.gradle/caches", name: "Gradle cache"),
            Candidate(kind: .devCache, path: "\(home)/.m2/repository", name: "Maven cache"),
            Candidate(kind: .devCache, path: "\(home)/go/pkg/mod", name: "Go module cache"),
            Candidate(kind: .devCache, path: "\(home)/.cargo/registry", name: "Cargo cache"),
            Candidate(kind: .devCache, path: "\(home)/.bun/install/cache", name: "Bun cache"),
            Candidate(kind: .otherCache, path: "\(home)/Library/Caches/ms-playwright", name: "Playwright browsers"),
            Candidate(kind: .trash, path: "\(home)/.Trash", name: "Trash"),
        ]
        let fm = FileManager.default
        // Each tool keeps its own folder under ~/.cache. Only the known download caches may be trashed.
        if let names = try? fm.contentsOfDirectory(atPath: "\(home)/.cache") {
            for name in names where !name.hasPrefix(".") {
                out.append(Candidate(kind: refillable.contains(name) ? .devCache : .otherCache, path: "\(home)/.cache/\(name)", name: "\(name) cache"))
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
                if owned {
                    // The cache of an installed app, named exactly after it: measured, and offered only while the app is closed.
                    if parts.count == name.components(separatedBy: ".").count, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
                        let app = (fm.displayName(atPath: url.path) as NSString).deletingPathExtension
                        out.append(Candidate(kind: .appCache, path: "\(home)/Library/Caches/\(name)", name: app, owner: name))
                    }
                    continue
                }
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
        // npx's downloads, one folder per package set. One that something runs from right now stays.
        let npx = "\(home)/.npm/_npx"
        if let names = try? fm.contentsOfDirectory(atPath: npx) {
            for name in names where !name.hasPrefix(".") {
                let path = "\(npx)/\(name)"
                if !inUse(path, by: usage) { out.append(Candidate(kind: .npx, path: path, name: name)) }
            }
        }
        // Claude Code's scratch folders: /private/tmp/claude-<uid>/<project>/<session>.
        let temp = "/private/tmp/claude-\(getuid())"
        if let projects = try? fm.contentsOfDirectory(atPath: temp) {
            for project in projects where !project.hasPrefix(".") {
                guard let sessions = try? fm.contentsOfDirectory(atPath: "\(temp)/\(project)") else { continue }
                for session in sessions where !session.hasPrefix(".") {
                    let path = "\(temp)/\(project)/\(session)"
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue, !inUse(path, by: usage) else { continue }
                    out.append(Candidate(kind: .claudeTemp, path: path, name: session))
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

    // MARK: - Claude worktrees

    /// git, without ever waking the "install the developer tools" dialog: /usr/bin/git is only a shim when they are missing.
    nonisolated static let git: String? = {
        let fm = FileManager.default
        if let own = ["/opt/homebrew/bin/git", "/usr/local/bin/git"].first(where: { fm.isExecutableFile(atPath: $0) }) { return own }
        let tools = ["/Library/Developer/CommandLineTools/usr/bin/git", "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
                     "/Applications/Xcode-beta.app/Contents/Developer/usr/bin/git"]
        return tools.contains(where: { fm.isExecutableFile(atPath: $0) }) ? "/usr/bin/git" : nil
    }()

    /// Projects Claude Code has opened: the keys of `projects` in ~/.claude.json.
    nonisolated static func claudeProjects() -> [String] {
        guard let data = FileManager.default.contents(atPath: "\(home)/.claude.json"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any] else { return [] }
        return Array(projects.keys)
    }

    /// Every linked worktree Claude made: `<project>/.claude/worktrees/<name>` whose `.git` is a file, never a symlink.
    nonisolated static func worktreeFolders() -> [(project: String, path: String)] {
        let fm = FileManager.default
        var seen = Set<String>()
        var out: [(project: String, path: String)] = []
        for project in claudeProjects() where !project.contains("/.claude/worktrees/") {
            let root = "\(project)/.claude/worktrees"
            guard (try? fm.destinationOfSymbolicLink(atPath: root)) == nil, let names = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for name in names where !name.hasPrefix(".") {
                let path = "\(root)/\(name)"
                var isDir: ObjCBool = false
                guard !seen.contains(path), (try? fm.destinationOfSymbolicLink(atPath: path)) == nil,
                      fm.fileExists(atPath: "\(path)/.git", isDirectory: &isDir), !isDir.boolValue else { continue }
                seen.insert(path)
                out.append((project, path))
            }
        }
        return out
    }

    /// The worktree's private git folder: its `.git` file reads "gitdir: …".
    nonisolated static func gitdir(_ worktree: String) -> String? {
        guard let text = try? String(contentsOfFile: "\(worktree)/.git", encoding: .utf8),
              let line = text.split(separator: "\n").first, line.hasPrefix("gitdir: ") else { return nil }
        let dir = String(line.dropFirst("gitdir: ".count)).trimmingCharacters(in: .whitespaces)
        return dir.hasPrefix("/") ? dir : (worktree as NSString).appendingPathComponent(dir)
    }

    /// When git last touched the worktree: its index, HEAD and HEAD log in the private git folder.
    nonisolated static func gitActivity(_ worktree: String) -> Date? {
        guard let dir = gitdir(worktree) else { return nil }
        let fm = FileManager.default
        return ["index", "HEAD", "logs/HEAD"].compactMap { (try? fm.attributesOfItem(atPath: "\(dir)/\($0)"))?[.modificationDate] as? Date }.max()
    }

    /// Nothing changed and nothing new: `git status` prints no line. Any failure counts as changed.
    nonisolated static func clean(_ worktree: String) async -> Bool {
        guard let git, let r = await Shell.run(git, ["-C", worktree, "--no-optional-locks", "status", "--porcelain"], timeout: 90),
              r.status == 0 else { return false }
        return r.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The worktree's commit is already on the project's main line: the default branch, here or on origin.
    nonisolated static func merged(_ worktree: String, project: String) async -> Bool {
        guard let git else { return false }
        var refs = ["main", "master", "origin/main", "origin/master"]
        if let r = await Shell.run(git, ["-C", project, "symbolic-ref", "--short", "refs/remotes/origin/HEAD"], timeout: 15), r.status == 0 {
            let remote = r.out.trimmingCharacters(in: .whitespacesAndNewlines)        // "origin/main"
            refs = [remote, remote.components(separatedBy: "/").dropFirst().joined(separator: "/")] + refs
        }
        var tried = Set<String>()
        for ref in refs where !ref.isEmpty && tried.insert(ref).inserted {
            if let r = await Shell.run(git, ["-C", worktree, "merge-base", "--is-ancestor", "HEAD", ref], timeout: 30), r.status == 0 { return true }
        }
        return false
    }

    /// Claude worktrees that git has not touched for a day and nothing runs inside, with what their state allows.
    nonisolated static func worktrees(using usage: Usage) async -> [DiskScan.Item] {
        let now = Date()
        let quiet = worktreeFolders().filter { f in
            guard let last = gitActivity(f.path), now.timeIntervalSince(last) >= 86_400 else { return false }
            return !inUse(f.path, by: usage)
        }
        var items: [DiskScan.Item] = []
        await withTaskGroup(of: DiskScan.Item?.self) { group in
            var pending = quiet[...]
            func launch(_ f: (project: String, path: String)) {
                group.addTask {
                    let state: DiskScan.Worktree
                    if !(await clean(f.path)) {
                        state = .dirty
                    } else {
                        state = await merged(f.path, project: f.project) ? .finished : .unmerged
                    }
                    guard let r = await Shell.run("/usr/bin/du", ["-sk", f.path], timeout: 120), r.status == 0,
                          let kb = UInt64(r.out.split(separator: "\t").first?.trimmingCharacters(in: .whitespaces) ?? "") else { return nil }
                    return DiskScan.Item(kind: .worktree, path: f.path, name: (f.path as NSString).lastPathComponent, bytes: kb << 10,
                                         modified: gitActivity(f.path), owner: f.project, state: state)
                }
            }
            var running = 0
            while running < 4, let f = pending.popFirst() { launch(f); running += 1 }
            for await item in group {
                if let item { items.append(item) }
                if let f = pending.popFirst() { launch(f) }
            }
        }
        return items
    }

    /// Why a worktree must stay right now, or nil when it may move: git touched it in the last ten minutes, something
    /// runs inside, or it has changes nobody committed.
    nonisolated static func worktreeHold(_ path: String, using usage: Usage) async -> String? {
        if let last = gitActivity(path), Date().timeIntervalSince(last) < 600 { return Copy.refusedBusy }
        if inUse(path, by: usage) { return Copy.refusedInUse }
        if !(await clean(path)) { return Copy.refusedChanges }
        return nil
    }

    /// True when anything inside was written within the window (minutes for caches, days for orphan caches).
    /// A folder a tool is filling right now must not move. When the check itself fails, assume busy.
    nonisolated static func recentlyWritten(_ path: String, minutes: Int? = nil, days: Int? = nil) async -> Bool {
        var args = [path]
        if let minutes { args += ["-mmin", "-\(minutes)"] } else if let days { args += ["-mtime", "-\(days)"] }
        args += ["-print", "-quit"]
        guard let r = await Shell.run("/usr/bin/find", args, timeout: 60) else { return true }
        return !r.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func scan() async -> DiskScan {
        let usage = Sampler.usage()
        let list = candidates(using: usage)
        var items: [DiskScan.Item] = []
        // du in small parallel batches; one slow tree must not hold the rest.
        await withTaskGroup(of: DiskScan.Item?.self) { group in
            var pending = list[...]
            var running = 0
            func launch(_ c: Candidate) {
                group.addTask {
                    guard let r = await Shell.run("/usr/bin/du", ["-sk", c.path], timeout: 60), r.status == 0,
                          let kb = UInt64(r.out.split(separator: "\t").first?.trimmingCharacters(in: .whitespaces) ?? "") else { return nil }
                    var item = DiskScan.Item(kind: c.kind, path: c.path, name: c.name, bytes: kb << 10, modified: c.modified, owner: c.owner)
                    // Folders that are only ever offered together are judged one by one, whatever their size.
                    switch c.kind {
                    case .npx:
                        item.busy = await recentlyWritten(c.path, days: 14)
                        return item
                    case .claudeTemp:
                        item.busy = await recentlyWritten(c.path, days: 3)
                        return item
                    default: break
                    }
                    guard item.bytes >= Tuning.standard.diskMin else { return item }
                    switch c.kind {
                    case .derivedData, .deviceSupport, .previews, .simCache, .devCache: item.busy = await recentlyWritten(c.path, minutes: 10)
                    case .orphanCache: item.busy = await recentlyWritten(c.path, days: 30)
                    default: break
                    }
                    return item
                }
            }
            while running < 4, let c = pending.popFirst() { launch(c); running += 1 }
            for await item in group {
                if let item { items.append(item) }
                if let c = pending.popFirst() { launch(c) }
            }
        }
        items += await worktrees(using: usage)
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
