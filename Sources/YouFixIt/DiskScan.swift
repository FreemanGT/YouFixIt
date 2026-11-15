import AppKit
import Foundation

/// Measures the disk side: caches that tools refill, leftovers of removed apps, old installers, simulator runtimes.
/// Slow (du) and rare (every six hours, or when the popover opens and the last look is over an hour old). Off the main actor.
enum DiskScanner {
    nonisolated static let home = NSHomeDirectory()
    /// Folders under ~/.cache that are plain download caches, refilled by their tool on the next run.
    /// Anything else there (browser installs, model files, a running tool's own data) is never part of Tidy up: it is
    /// explained, with a Move to Trash button for when the user decides.
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

    /// The checkout's private git folder: a worktree's `.git` file reads "gitdir: …"; a clone's `.git` is the folder itself.
    nonisolated static func gitdir(_ worktree: String) -> String? {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: "\(worktree)/.git", isDirectory: &isDir), isDir.boolValue,
           (try? FileManager.default.destinationOfSymbolicLink(atPath: "\(worktree)/.git")) == nil { return "\(worktree)/.git" }
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

    /// Ignored folders that tools build again (dependencies, build output, caches, generated code), and ignored files nobody
    /// misses, Claude's own preview settings among them. Not tmp or out: notes and rendered files live there too.
    nonisolated static let regrows: Set<String> = [
        "node_modules", ".next", ".nuxt", ".svelte-kit", ".turbo", ".vercel", ".expo", ".parcel-cache", ".cache", ".wrangler", ".astro",
        ".angular", ".docusaurus", "dist", "build", ".build", "target", "coverage", "storybook-static", "playwright-report",
        "test-results", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".venv", "venv", ".tox", "Pods", "DerivedData",
        ".gradle", ".dart_tool", "vendor", "log", "logs", "generated", "__generated__",
    ]
    nonisolated static let throwaway: Set<String> = [".DS_Store", "settings.local.json", "next-env.d.ts", ".eslintcache"]

    /// A path that regrows (a dependency or build folder anywhere in it) or that nobody misses.
    nonisolated static func disposable(_ path: String) -> Bool {
        let parts = path.split(separator: "/").map(String.init)
        if parts.contains(where: { regrows.contains($0) }) { return true }
        guard let last = parts.last else { return true }
        if throwaway.contains(last) || last.hasSuffix(".log") || last.hasSuffix(".tsbuildinfo") { return true }
        return path == ".claude/launch.json" || path.hasSuffix("/.claude/launch.json")
    }

    /// What `git status --porcelain -z --ignored` shows living only in this worktree. A change, a staged file or one git
    /// does not track is work. An ignored file is local (an .env, a scratch folder) unless it is disposable or the main
    /// checkout has the same file (`isCopy`). An ignored folder is looked into: `inside` lists its files, nil when it is
    /// too big or can't be read, and then nobody can vouch for it. Another worktree or repository inside is work too.
    nonisolated static func keeps(_ status: String, isCopy: (String) -> Bool, inside: (String) -> [String]?) -> DiskScan.Keeps {
        var found = DiskScan.Keeps.nothing
        for entry in status.split(separator: "\0").map(String.init) where !entry.isEmpty {
            guard entry.hasPrefix("!! ") else { return .work }
            let raw = String(entry.dropFirst(3))
            let path = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if disposable(path) || isCopy(path) { continue }
            if raw.hasSuffix("/") {
                guard let files = inside(path) else { return .work }
                if files.contains(where: { $0.split(separator: "/").contains(".git") }) { return .work }
                if files.allSatisfy({ disposable("\(path)/\($0)") || isCopy("\(path)/\($0)") }) { continue }
            }
            found = .local
        }
        return found
    }

    /// What lives only in the worktree, its ignored files compared with the main checkout's (none for a clone). Any failure
    /// counts as work.
    nonisolated static func keeps(_ worktree: String, project: String?) async -> DiskScan.Keeps {
        guard let git, let r = await Shell.run(git, ["-C", worktree, "--no-optional-locks", "status", "--porcelain", "-z",
                                                     "--untracked-files=normal", "--ignored", "--ignore-submodules=none"], timeout: 90),
              r.status == 0 else { return .work }
        // Files git was told to stop looking at (assume-unchanged, skip-worktree, a sparse checkout) can hide edits from status.
        guard let tracked = await Shell.run(git, ["-C", worktree, "--no-optional-locks", "ls-files", "-v", "-z"], timeout: 60),
              tracked.status == 0 else { return .work }
        if tracked.out.split(separator: "\0").contains(where: { $0.first.map { $0.isLowercase || $0 == "S" } ?? false }) { return .work }
        let fm = FileManager.default
        return keeps(r.out, isCopy: { path in
            var isDir: ObjCBool = false
            let mine = "\(worktree)/\(path)"
            guard let project, fm.fileExists(atPath: mine, isDirectory: &isDir), !isDir.boolValue else { return false }
            return fm.contentsEqual(atPath: mine, andPath: "\(project)/\(path)")
        }, inside: { files(in: "\(worktree)/\($0)", limit: 400) })
    }

    /// The files under a folder, relative to it, without following links or entering folders that regrow. A `.git` (another
    /// worktree or repository) is listed as itself. nil past `limit`, or when any part can't be read.
    nonisolated static func files(in folder: String, limit: Int) -> [String]? {
        let fm = FileManager.default
        guard fm.isReadableFile(atPath: folder), fm.isExecutableFile(atPath: folder), let walker = fm.enumerator(atPath: folder) else { return nil }
        var out: [String] = []
        while let rel = walker.nextObject() as? String {
            guard let type = walker.fileAttributes?[.type] as? FileAttributeType else { return nil }
            let name = (rel as NSString).lastPathComponent
            switch type {
            case .typeDirectory:
                if name == ".git" {
                    out.append(rel)
                    walker.skipDescendants()
                } else if regrows.contains(name) {
                    walker.skipDescendants()
                } else if !fm.isReadableFile(atPath: "\(folder)/\(rel)") || !fm.isExecutableFile(atPath: "\(folder)/\(rel)") {
                    return nil
                }
            case .typeRegular:
                out.append(rel)
                if out.count > limit { return nil }
            default:
                continue        // a link holds no data of its own, nor does a socket or a pipe
            }
        }
        return out
    }

    /// git is in the middle of something here (a rebase, a merge, a cherry-pick, a bisect), or the worktree is locked. A lock
    /// left by a Claude session that has since ended (`staleLock`) holds nothing back.
    nonisolated static func unfinished(_ worktree: String) -> Bool {
        guard let dir = gitdir(worktree) else { return true }
        let fm = FileManager.default
        if ["rebase-merge", "rebase-apply", "MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "BISECT_LOG"].contains(where: { fm.fileExists(atPath: "\(dir)/\($0)") }) {
            return true
        }
        return fm.fileExists(atPath: "\(dir)/locked") && !staleLock(worktree)
    }

    /// The worktree is locked by a Claude session that is gone: its lock names a process that no longer runs, or a process
    /// with that number that started at another time (the number was reused).
    nonisolated static func staleLock(_ worktree: String) -> Bool {
        guard let dir = gitdir(worktree), let reason = try? String(contentsOfFile: "\(dir)/locked", encoding: .utf8) else { return false }
        return lockStale(reason, process: process)
    }

    /// Claude Code locks a worktree with the reason "claude session <name> (pid <n> start <date>)" ("claude agent …" for an
    /// agent's), the date as `LC_ALL=C TZ=UTC ps -o lstart=` prints it, and without it when ps gave none. Any other lock is
    /// someone's own and stays. A start date that can't be read only lets the lock go once the process is gone.
    nonisolated static func lockStale(_ reason: String, process: (pid_t) -> (alive: Bool, start: Date?)) -> Bool {
        guard let lock = claudeLock(reason) else { return false }
        let now = process(lock.pid)
        guard now.alive else { return true }
        guard let then = lock.start, let started = now.start else { return false }
        return abs(then.timeIntervalSince1970 - started.timeIntervalSince1970.rounded(.down)) >= 1
    }

    /// The process number and start time in a Claude Code lock reason, or nil when someone else locked it.
    nonisolated static func claudeLock(_ reason: String) -> (pid: pid_t, start: Date?)? {
        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pattern = try? NSRegularExpression(pattern: #"^claude (?:agent|session) .{1,255} \(pid (\d{1,10})(?: start (.{1,255}))?\)$"#),
              let m = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let pidRange = Range(m.range(at: 1), in: text), let pid = Int32(text[pidRange]) else { return nil }
        let start = Range(m.range(at: 2), in: text).flatMap { lstart(String(text[$0])) }
        return (pid, start)
    }

    /// "Sat Nov 15 09:12:03 2026" (or "Sun Nov  2 …"), UTC, as `ps -o lstart=` prints it under LC_ALL=C TZ=UTC.
    nonisolated static func lstart(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        return f.date(from: text.split(separator: " ").joined(separator: " "))
    }

    /// Whether a process runs, and since when. One of another user's still runs, its start unknown.
    nonisolated static func process(_ pid: pid_t) -> (alive: Bool, start: Date?) {
        guard pid > 1 else { return (false, nil) }
        var bsd = proc_bsdinfo()
        if proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 {
            return (true, Date(timeIntervalSince1970: TimeInterval(bsd.pbi_start_tvsec) + TimeInterval(bsd.pbi_start_tvusec) / 1_000_000))
        }
        return (kill(pid, 0) == 0 || errno == EPERM, nil)
    }

    /// HEAD is a commit rather than a branch, so its commits may be on no branch at all.
    nonisolated static func detached(_ worktree: String) -> Bool {
        guard let dir = gitdir(worktree), let head = try? String(contentsOfFile: "\(dir)/HEAD", encoding: .utf8) else { return true }
        return !head.hasPrefix("ref: ")
    }

    /// The project a Claude worktree belongs to: the folder that holds `.claude/worktrees`.
    nonisolated static func worktreeProject(_ path: String) -> String? {
        path.range(of: "/.claude/worktrees/").map { String(path[..<$0.lowerBound]) }
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
                    // Finished: its work is on the main line and nothing lives only here. Unmerged: its commits are on a
                    // branch, which keeps them. Either may hold local files git ignores. Anything else is only explained.
                    let found: DiskScan.Keeps = unfinished(f.path) ? .work : await keeps(f.path, project: f.project)
                    let state: DiskScan.Worktree
                    if found == .work {
                        state = .dirty
                    } else if await merged(f.path, project: f.project) {
                        state = found == .local ? .finishedLocal : .finished
                    } else if detached(f.path) {
                        state = .dirty
                    } else {
                        state = found == .local ? .unmergedLocal : .unmerged
                    }
                    guard let r = await Shell.run("/usr/bin/du", ["-sk", f.path], timeout: 120), r.status == 0,
                          let kb = UInt64(r.out.split(separator: "\t").first?.trimmingCharacters(in: .whitespaces) ?? "") else { return nil }
                    return DiskScan.Item(kind: .worktree, path: f.path, name: (f.path as NSString).lastPathComponent, bytes: kb << 10,
                                         modified: gitActivity(f.path), owner: f.project, state: state, staleLock: staleLock(f.path))
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

    /// Why a worktree must stay right now, or nil when it may move. Everything that made its row is checked again: quiet
    /// for a day, nothing running inside, git not mid-operation, no work found only here. `strict` is the pre-selected
    /// row: nothing at all may live only there and its work must still be merged. A pressed button may take local files
    /// along (its row said so), as long as the commits are merged or on a branch.
    nonisolated static func worktreeHold(_ path: String, using usage: Usage, strict: Bool) async -> String? {
        if let last = gitActivity(path), Date().timeIntervalSince(last) < 86_400 { return Copy.refusedRecent }
        if inUse(path, by: usage) { return Copy.refusedInUse }
        guard let project = worktreeProject(path), !unfinished(path) else { return Copy.refusedChanges }
        let found = await keeps(path, project: project)
        if found == .work || (strict && found == .local) { return Copy.refusedChanges }
        let isMerged = await merged(path, project: project)
        if strict && !isMerged { return Copy.refusedUnmerged }
        if !isMerged && detached(path) { return Copy.refusedChanges }
        return nil
    }

    // MARK: - Git checkouts in Claude's scratch folders

    /// Every git checkout in a scratch folder: a folder holding a `.git` (a clone's folder, a worktree's file), the folder
    /// itself included, at most `depth` levels down. Links are not followed, folders that regrow are not entered, nor is a
    /// checkout once found (git status sees what lives inside it). nil past `limit` entries or when a part can't be read:
    /// then nobody can vouch for the folder.
    nonisolated static func checkouts(in folder: String, depth: Int = 5, limit: Int = 50_000) -> [String]? {
        let fm = FileManager.default
        if fm.fileExists(atPath: "\(folder)/.git") { return [folder] }
        guard fm.isReadableFile(atPath: folder), fm.isExecutableFile(atPath: folder), let walker = fm.enumerator(atPath: folder) else { return nil }
        var out: [String] = []
        var seen = 0
        while let rel = walker.nextObject() as? String {
            seen += 1
            if seen > limit { return nil }
            guard let type = walker.fileAttributes?[.type] as? FileAttributeType else { return nil }
            guard type == .typeDirectory else { continue }
            let path = "\(folder)/\(rel)"
            if fm.fileExists(atPath: "\(path)/.git") {
                out.append(path)
                walker.skipDescendants()
            } else if regrows.contains((rel as NSString).lastPathComponent) || walker.level >= depth {
                walker.skipDescendants()
            } else if !fm.isReadableFile(atPath: path) || !fm.isExecutableFile(atPath: path) {
                return nil
            }
        }
        return out
    }

    /// The main checkout of a linked worktree: the folder that holds the `.git` its gitdir lives in.
    nonisolated static func mainCheckout(_ worktree: String) -> String? {
        guard let dir = gitdir(worktree), let r = dir.range(of: "/.git/worktrees/") else { return nil }
        return String(dir[..<r.lowerBound])
    }

    /// A clone has commits no remote-tracking ref holds: on a branch, a tag, a stash or HEAD that was never pushed, or
    /// anything at all when it has no remote. A failure counts as unpushed.
    nonisolated static func unpushed(_ clone: String) async -> Bool {
        guard let git, let r = await Shell.run(git, ["-C", clone, "--no-optional-locks", "rev-list", "-n", "1", "--all", "--not", "--remotes"], timeout: 60),
              r.status == 0 else { return true }
        return !r.out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A git checkout in a scratch folder holds work found nowhere else, judged as strictly as the pre-selected worktree
    /// row: git mid-operation or locked by a live session, changes, new or local files, and then for a worktree a commit
    /// that is not on its project's main line (commits on no branch, or on a branch not merged yet), for a clone a commit
    /// no remote holds.
    nonisolated static func checkoutHolds(_ checkout: String) async -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: "\(checkout)/.git", isDirectory: &isDir) else { return true }
        if unfinished(checkout) { return true }
        let main = isDir.boolValue ? nil : mainCheckout(checkout)
        if await keeps(checkout, project: main) != .nothing { return true }
        if isDir.boolValue { return await unpushed(checkout) }
        return !(await merged(checkout, project: main ?? checkout))
    }

    /// A Claude scratch folder holds git work that would be lost with it, or can't be looked through.
    nonisolated static func scratchHolds(_ folder: String) async -> Bool {
        guard let found = checkouts(in: folder) else { return true }
        for checkout in found {
            if await checkoutHolds(checkout) { return true }
        }
        return false
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
                        if !item.busy { item.holdsWork = await scratchHolds(c.path) }
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
