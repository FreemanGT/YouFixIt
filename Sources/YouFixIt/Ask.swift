import AppKit
import SwiftUI

/// Ask Claude: one row, or every row, handed to a new Claude chat as a plain question. Claude gets words, never hands:
/// nothing here changes the Mac. The question carries what YouFixIt already knows (what the row is, what its button would
/// do, the folders and command lines behind it), with the home folder written as ~ and anything that looks like a password
/// or a token blanked out.
enum Ask {
    /// The Claude app keeps the first 14,336 characters of a question; a claude.ai link also has to pass web servers, which
    /// turn away very long addresses. Rows past this are counted, not described.
    static let limit = 6000
    static let claudeApp = "com.anthropic.claudefordesktop"

    /// A new chat with the question filled in: in the Claude app when it is the one that opens claude:// links, else on
    /// claude.ai in the browser.
    @MainActor
    static func open(_ rows: [Finding], sample: Sample?) {
        guard !rows.isEmpty, let probe = URL(string: "claude://claude.ai/new") else { return }
        let handler = NSWorkspace.shared.urlForApplication(toOpen: probe).flatMap { Bundle(url: $0)?.bundleIdentifier }
        NSWorkspace.shared.open(url(question(rows, sample: sample), app: handler == claudeApp))
    }

    /// Letters, digits and -._~ stay as they are; everything else is escaped. The Claude app reads the link with
    /// URLSearchParams, which would read a bare + as a space.
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// The Claude app's own Ask Claude service opens `claude://claude.ai/new?q=…&surface=chat`; claude.ai takes `/new?q=…`.
    static func url(_ question: String, app: Bool) -> URL {
        let q = question.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
        return URL(string: app ? "claude://claude.ai/new?q=\(q)&surface=chat" : "https://claude.ai/new?q=\(q)")!
    }

    // MARK: - The question

    /// What to answer, how YouFixIt acts, one block per row, and how to answer.
    static func question(_ rows: [Finding], sample: Sample?, home: String = DiskScanner.home) -> String {
        let many = rows.count > 1
        var text = [many ? Copy.askMany(rows.count) : Copy.askOne, Copy.askHow].joined(separator: "\n\n")
        let end = "\n\n" + Copy.askEnd
        for (i, f) in rows.enumerated() {
            var lines = describe(f, sample: sample, home: home, brief: many)
            if many { lines = ["\(i + 1). \(lines[0])"] + lines.dropFirst().map { "   \($0)" } }
            let block = "\n\n" + lines.joined(separator: "\n")
            // Room for the line that counts what is left out, unless this is the last row.
            let reserve = i < rows.count - 1 ? 80 : 0
            if text.count + block.count + end.count + reserve > limit {
                text += "\n\n" + Copy.askMore(rows.count - i)
                break
            }
            text += block
        }
        return text + end
    }

    /// One row as plain lines: its name, where YouFixIt lists it and how big it is, YouFixIt's reason, what its button
    /// does, then what it is on the Mac. `brief` (one row among many) keeps that last part to a line or two.
    static func describe(_ f: Finding, sample: Sample?, home: String, brief: Bool = false) -> [String] {
        [f.name, Copy.askWhere(f.group, bytes: f.bytes, disk: onDisk(f)), Copy.askSays(f.why), Copy.askButton(f.action)]
            + details(f, sample: sample, home: home, brief: brief)
    }

    /// Whether a row's size is disk space rather than memory.
    static func onDisk(_ f: Finding) -> Bool {
        switch f.action {
        case .trash, .trashAll, .emptyTrash, .deleteRuntime, .deleteDevice, .deleteUnavailableSims: true
        case nil: f.group == .space || (f.link?.url.hasPrefix("/") ?? false)
        default: false
        }
    }

    /// The folders, programs and apps behind a row.
    static func details(_ f: Finding, sample: Sample?, home: String, brief: Bool = false) -> [String] {
        switch f.action {
        case .quitApp(_, let bundleID, let url):
            return [Copy.askApp(bundleID, path: url.map { tilde($0.path, home: home) })]
        case .sigterm(let pid, _), .stopService(_, let pid, _):
            return program(pid, sample: sample, home: home, brief: brief)
        case .sigtermAll(let targets), .endSessions(let targets):
            let n = brief ? 3 : 6
            let shown = targets.prefix(n).flatMap { program($0.pid, sample: sample, home: home, brief: true) }
            return shown + (targets.count > n ? [Copy.askAndMore(targets.count - n)] : [])
        case .trash(let path):
            return [Copy.askFolder(tilde(path, home: home))]
        case .trashAll(let targets):
            return folders(targets, home: home, brief: brief)
        case .deleteRuntime(let id):
            return [Copy.askRuntime(id)]
        case .shutdownSim, .deleteDevice, .deleteUnavailableSims, .stopBackup, .restart, .emptyTrash:
            return []
        case nil:
            guard let path = f.link?.url, path.hasPrefix("/") else { return [] }
            return [Copy.askFolder(tilde(path, home: home))]
        }
    }

    /// Many folders as the folder they share and how many there are; unless `brief`, the biggest few by name as well.
    static func folders(_ targets: [Finding.TrashTarget], home: String, brief: Bool) -> [String] {
        guard targets.count > 1 else { return targets.map { Copy.askFolder(tilde($0.path, home: home)) } }
        let parent = commonParent(targets.map(\.path))
        let biggest: [String] = brief ? [] : targets.sorted { $0.bytes > $1.bytes }.prefix(5).map { t -> String in
            var name = String(t.path.dropFirst(parent == "/" ? 1 : parent.count + 1))
            name = tilde(name, home: home)
            if name.count > 72 { name = String(name.prefix(34)) + "…" + String(name.suffix(34)) }
            return "\(name) (\(Format.size(t.bytes)))"
        }
        return [Copy.askFolders(targets.count, in: tilde(parent, home: home), biggest: biggest)]
    }

    /// The deepest folder that holds every one of these paths.
    static func commonParent(_ paths: [String]) -> String {
        let split = paths.map { ($0 as NSString).deletingLastPathComponent.split(separator: "/") }
        guard var common = split.first else { return "/" }
        for parts in split.dropFirst() {
            var i = 0
            while i < common.count, i < parts.count, common[i] == parts[i] { i += 1 }
            common = Array(common.prefix(i))
        }
        return "/" + common.joined(separator: "/")
    }

    /// A program as the last sample saw it: its command line (or its path), and unless `brief`, its ports, its working
    /// folder and when it started.
    static func program(_ pid: pid_t, sample: Sample?, home: String, brief: Bool = false) -> [String] {
        guard let s = sample, let p = s.procs[pid] else { return [] }
        let args = s.args[pid].flatMap { args in args.contains { !$0.isEmpty } ? args : nil } ?? [p.path.isEmpty ? p.name : p.path]
        let ports = Rules.ports(of: s.tree(pid), in: s)
        if brief { return [Copy.askCommand(commandLine(args, home: home)) + (ports.isEmpty ? "" : ", \(Copy.askPorts(ports).lowercased())")] }
        var lines = [Copy.askCommand(commandLine(args, home: home))]
        if !ports.isEmpty { lines.append(Copy.askPorts(ports)) }
        if let cwd = s.cwd[pid] { lines.append(Copy.askCwd(tilde(cwd, home: home))) }
        lines.append(Copy.askSince(p.start))
        return lines
    }

    // MARK: - Fit to share

    /// The home folder as ~, also inside the dashed folder names Claude makes from paths (-Users-me-Project). A longer
    /// name that only starts the same (/Users/meredith) is left alone.
    static func tilde(_ text: String, home: String) -> String {
        guard home.count > 1 else { return text }
        let dashed = home.replacingOccurrences(of: "/", with: "-")
        return text
            .replacingOccurrences(of: NSRegularExpression.escapedPattern(for: home) + "(?![A-Za-z0-9._-])", with: "~", options: .regularExpression)
            .replacingOccurrences(of: NSRegularExpression.escapedPattern(for: dashed) + "(?![A-Za-z0-9._])", with: "~", options: .regularExpression)
    }

    /// Words in a flag or variable name that say its value is a secret; any word holding one of `secretParts` counts too
    /// (PGPASSWORD, x-api-token).
    static let secretWords: Set<String> = ["key", "pass", "pwd", "auth", "authorization", "credential", "credentials", "cookie", "session",
                                           "private", "signature", "bearer"]
    static let secretParts = ["password", "passwd", "secret", "token", "apikey"]

    static func secret(_ name: String) -> Bool {
        // apiKey and api_key read alike: words split at anything not a letter or digit, and where lower case meets upper.
        var words: [String] = []
        var word = ""
        var lastLower = false
        for c in name {
            if !(c.isLetter || c.isNumber) || (c.isUppercase && lastLower) {
                if !word.isEmpty { words.append(word.lowercased()) }
                word = c.isLetter || c.isNumber ? String(c) : ""
            } else {
                word.append(c)
            }
            lastLower = c.isLowercase
        }
        if !word.isEmpty { words.append(word.lowercased()) }
        return words.contains { w in secretWords.contains(w) || secretParts.contains { w.contains($0) } }
    }

    /// A command line fit to share: home as ~, the values of secret-sounding flags and variables blanked, credentials in
    /// links and long token-like strings blanked, cut to a couple of lines. A tool that renamed itself leaves its whole
    /// line in one argument, so arguments are read word by word.
    static func commandLine(_ args: [String], home: String) -> String {
        var out: [String] = []
        var hideNext = false
        for word in args.flatMap({ $0.split(separator: " ").map(String.init) }) {
            if hideNext, !word.hasPrefix("-") {
                out.append("…")
                hideNext = false
                continue
            }
            hideNext = false
            var w = word
            if let eq = w.firstIndex(of: "="), eq != w.startIndex, secret(String(w[..<eq])) {
                w = String(w[...eq]) + "…"
            } else if w.hasPrefix("-"), secret(w) {
                hideNext = true
            }
            out.append(blank(tilde(w, home: home)))
        }
        let line = out.joined(separator: " ")
        return line.count > 240 ? String(line.prefix(239)) + "…" : line
    }

    /// Credentials inside links (scheme://user:pass@host) and runs of 24 or more letters, digits, _ or - that hold both
    /// letters and digits (API keys, session tokens), blanked.
    static func blank(_ text: String) -> String {
        var s = text.replacingOccurrences(of: #"([A-Za-z][A-Za-z0-9+.-]*://)[^/@\s]+@"#, with: "$1…@", options: .regularExpression)
        guard let runs = try? NSRegularExpression(pattern: "[A-Za-z0-9_-]{24,}") else { return s }
        for m in runs.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed() {
            guard let r = Range(m.range, in: s) else { continue }
            let run = s[r]
            if run.contains(where: \.isLetter), run.contains(where: \.isNumber) { s.replaceSubrange(r, with: "…") }
        }
        return s
    }
}

/// The sparkle on a row that asks Claude what it is and whether it can go. Shown with Keep or Hide while the pointer is
/// over the row.
struct AskButton: View {
    static let symbol = "sparkles"
    let name: String
    var step: Theme.Step = .bodyStrong
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: Self.symbol).font(Theme.font(step))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.tintText)
        .help(Copy.askTip)
        .accessibilityLabel(Copy.a11yAsk(name))
    }
}
