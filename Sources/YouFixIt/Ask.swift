import AppKit
import SwiftUI

/// Ask Claude: one row, or every row, handed to a new Claude chat as a plain question. Claude gets words, never hands:
/// nothing here changes the Mac. The question carries what YouFixIt already knows (what the row is, what its button would
/// do, the folders and command lines behind it), passed through `Redact` first.
enum Ask {
    /// The Claude app keeps the first 14,336 characters of a question, and a claude.ai link has to get past web servers,
    /// which turn away very long addresses. Rows past either limit are counted, not described.
    static let limit = 6000
    /// The question as it travels, escaped: every character outside ASCII takes 6 to 12 bytes.
    static let linkLimit = 12_000
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

    private static func escaped(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "" }

    /// The Claude app's own Ask Claude service opens `claude://claude.ai/new?q=…&surface=chat`; claude.ai takes `/new?q=…`.
    static func url(_ question: String, app: Bool) -> URL {
        let q = escaped(question)
        return URL(string: app ? "claude://claude.ai/new?q=\(q)&surface=chat" : "https://claude.ai/new?q=\(q)")!
    }

    // MARK: - The question

    /// What to answer, how YouFixIt acts, one block per row, and how to answer.
    static func question(_ rows: [Finding], sample: Sample?, home: String = DiskScanner.home) -> String {
        let many = rows.count > 1
        var text = [many ? Copy.askMany(rows.count) : Copy.askOne, Copy.askHow].joined(separator: "\n\n")
        let end = "\n\n" + Copy.askEnd
        var size = escaped(text).utf8.count + escaped(end).utf8.count
        for (i, f) in rows.enumerated() {
            var lines = describe(f, sample: sample, home: home, brief: many)
            if many { lines = ["\(i + 1). \(lines[0])"] + lines.dropFirst().map { "   \($0)" } }
            let block = "\n\n" + lines.joined(separator: "\n")
            let cost = escaped(block).utf8.count
            // Room for the line that counts what is left out, unless this is the last row.
            let reserve = i < rows.count - 1 ? 80 : 0
            if text.count + block.count + end.count + reserve > limit || size + cost + reserve * 3 > linkLimit {
                text += "\n\n" + Copy.askMore(rows.count - i)
                break
            }
            text += block
            size += cost
        }
        return text + end
    }

    /// One row as plain lines: its name, where YouFixIt lists it and how big it is, YouFixIt's reason, what its button
    /// does, then what it is on the Mac. `brief` (one row among many) keeps that last part to a line or two.
    static func describe(_ f: Finding, sample: Sample?, home: String, brief: Bool = false) -> [String] {
        [Redact.text(f.name, home: home), Copy.askWhere(f.group, bytes: f.bytes, disk: onDisk(f)), Copy.askSays(Redact.text(f.why, home: home)),
         Copy.askButton(f.action)] + details(f, sample: sample, home: home, brief: brief)
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
            return [Copy.askApp(bundleID, path: url.map { Redact.tilde($0.path, home: home) })]
        case .quitApps(let apps):
            let n = brief ? 3 : 6
            let shown = apps.prefix(n).map { Copy.askApp($0.bundleID, path: $0.url.map { Redact.tilde($0.path, home: home) }) }
            return shown + (apps.count > n ? [Copy.askAndMore(apps.count - n)] : [])
        case .sigterm(let pid, _), .stopService(_, let pid, _):
            return program(pid, sample: sample, home: home, brief: brief)
        case .sigtermAll(let targets), .endSessions(let targets):
            let n = brief ? 3 : 6
            let shown = targets.prefix(n).flatMap { program($0.pid, sample: sample, home: home, brief: true) }
            return shown + (targets.count > n ? [Copy.askAndMore(targets.count - n)] : [])
        case .trash(let path):
            return [Copy.askFolder(Redact.tilde(path, home: home))]
        case .trashAll(let targets):
            return folders(targets, home: home, brief: brief)
        case .deleteRuntime(let id):
            return [Copy.askRuntime(id)]
        case .shutdownSim, .deleteDevice, .deleteUnavailableSims, .stopBackup, .restart, .emptyTrash:
            return []
        case nil:
            guard let path = f.link?.url, path.hasPrefix("/") else { return [] }
            return [Copy.askFolder(Redact.tilde(path, home: home))]
        }
    }

    /// Many folders as the folder they share and how many there are; unless `brief`, the biggest few by name as well.
    static func folders(_ targets: [Finding.TrashTarget], home: String, brief: Bool) -> [String] {
        guard targets.count > 1 else { return targets.map { Copy.askFolder(Redact.tilde($0.path, home: home)) } }
        // Each path goes to ~ whole, before the shared part comes off, so a home folder split across the two still goes.
        let parent = Redact.tilde(commonParent(targets.map(\.path)), home: home)
        let biggest: [String] = brief ? [] : targets.sorted { $0.bytes > $1.bytes }.prefix(5).map { t -> String in
            let full = Redact.tilde(t.path, home: home)
            var name = full.hasPrefix(parent + "/") ? String(full.dropFirst(parent.count + 1)) : full
            if parent == "/", name.hasPrefix("/") { name.removeFirst() }
            if name.count > 72 { name = String(name.prefix(34)) + "…" + String(name.suffix(34)) }
            return "\(name) (\(Format.size(t.bytes)))"
        }
        return [Copy.askFolders(targets.count, in: parent, biggest: biggest)]
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
        let line = Copy.askCommand(Redact.commandLine(args, home: home))
        let ports = Rules.ports(of: s.tree(pid), in: s)
        if brief { return [line + (ports.isEmpty ? "" : ", \(Copy.askPorts(ports).lowercased())")] }
        var lines = [line]
        if !ports.isEmpty { lines.append(Copy.askPorts(ports)) }
        if let cwd = s.cwd[pid] { lines.append(Copy.askCwd(Redact.tilde(cwd, home: home))) }
        lines.append(Copy.askSince(p.start))
        return lines
    }
}

/// What a question may say about this Mac: the home folder as ~, and nothing that looks like a password, a token or a key.
/// Blanking too much costs a little detail; blanking too little sends a secret to a chat, so every rule errs wide.
enum Redact {
    /// Words in a flag, variable, header or JSON key that say its value is a secret, and parts that do so inside a longer
    /// word (PGPASSWORD, privateKey, x-api-token). "pat" stays a whole word, or every --path would go.
    static let secretWords: Set<String> = ["pass", "pwd", "pat", "auth", "oauth", "authorization", "cookie", "session", "private", "signature",
                                           "bearer", "jwt", "otp", "sig"]
    static let secretParts = ["password", "passwd", "passphrase", "secret", "token", "key", "credential"]
    /// Words that put the secret in the next word: "Authorization: Bearer xyz".
    static let schemes: Set<String> = ["bearer", "basic", "token", "digest"]

    static func secret(_ name: String) -> Bool {
        words(name).contains { w in secretWords.contains(w) || secretParts.contains { w.contains($0) } }
    }

    /// apiKey, api_key and API-KEY read alike: words split at anything not a letter or digit, and where lower case meets upper.
    static func words(_ name: String) -> [String] {
        var out: [String] = []
        var word = ""
        var lastLower = false
        for c in name {
            if !(c.isLetter || c.isNumber) || (c.isUppercase && lastLower) {
                if !word.isEmpty { out.append(word.lowercased()) }
                word = c.isLetter || c.isNumber ? String(c) : ""
            } else {
                word.append(c)
            }
            lastLower = c.isLowercase
        }
        if !word.isEmpty { out.append(word.lowercased()) }
        return out
    }

    /// The home folder as ~, also inside the dashed folder names Claude makes from paths, where every character that is
    /// not a letter or digit turns into "-" (/Users/first.last becomes -Users-first-last). A longer name that only starts
    /// the same (/Users/meredith) is left alone.
    static func tilde(_ text: String, home: String) -> String {
        guard home.count > 1 else { return text }
        var out = text.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: home) + "(?![A-Za-z0-9._-])", with: "~", options: .regularExpression)
        let dashed = [home.replacingOccurrences(of: "/", with: "-"), String(home.map { $0.isLetter || $0.isNumber ? $0 : "-" })]
        for d in Set(dashed) {
            out = out.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: d) + "(?![A-Za-z0-9._])", with: "~", options: .regularExpression)
        }
        return out
    }

    /// Any text that may hold a path or a secret (a row's name, a folder, a joined command line): ~ for home, then the
    /// values of secret keys, credentials in links and long token-like runs blanked.
    static func text(_ s: String, home: String) -> String {
        longRuns(credentials(keyedValues(tilde(s, home: home))))
    }

    /// A command line fit to share, read argument by argument so a value with spaces goes whole. A tool that renamed
    /// itself leaves its whole line in one argument, which is read word by word instead.
    static func commandLine(_ args: [String], home: String) -> String {
        let given = args.filter { !$0.isEmpty }
        let units = given.count == 1 ? given[0].split(separator: " ").map(String.init) : given
        let program = ((units.first ?? "") as NSString).lastPathComponent.lowercased()
        var out: [String] = []
        var hideNext = false
        var userNext = false
        for u in units {
            if hideNext, !u.hasPrefix("-") {
                out.append("…")
                hideNext = schemes.contains(u.lowercased())       // "Bearer" hidden: the token after it goes too
                continue
            }
            hideNext = false
            if userNext {
                userNext = false
                if let colon = u.firstIndex(of: ":") { out.append(String(u[...colon]) + "…"); continue }   // curl -u user:password
            }
            if let sep = u.firstIndex(where: { $0 == "=" || $0 == ":" }), sep != u.startIndex, secret(String(u[..<sep])) {
                // NAME=value, --secret:value, X-Api-Key: value, {"password": …: everything after the name goes.
                out.append(String(u[...sep]) + "…")
                hideNext = u.index(after: sep) == u.endIndex     // "X-Api-Key:" with its value in the next word
            } else if u.hasPrefix("-"), secret(u) {
                out.append(u)                                   // --password hunter2
                hideNext = true
            } else if schemes.contains(u.lowercased()) {
                out.append(u)                                   // Authorization: Bearer xyz, word by word
                hideNext = true
            } else if program.hasPrefix("mysql") || program.hasPrefix("mariadb"), u.hasPrefix("-p"), !u.hasPrefix("--"), u.count > 2 {
                out.append("-p…")                               // mysql -phunter2
            } else {
                userNext = u == "-u" || u == "--user"
                out.append(u)
            }
        }
        let line = text(out.joined(separator: " "), home: home)
        return line.count > 240 ? String(line.prefix(239)) + "…" : line
    }

    /// Arguments without the values of secret flags (--token abc, --api-key=abc), for the names rows are given.
    static func withoutSecrets(_ args: [String]) -> [String] {
        var out: [String] = []
        var skip = false
        for a in args {
            if skip, !a.hasPrefix("-") { skip = false; continue }
            skip = false
            if let eq = a.firstIndex(of: "="), eq != a.startIndex, secret(String(a[..<eq])) { continue }
            if a.hasPrefix("-"), secret(a) { skip = true; continue }
            out.append(a)
        }
        return out
    }

    /// The value after any secret key inside text: "password":"x" in JSON, &token=x in a query string, X-Api-Key: x in a
    /// header, with a Bearer or Basic before it taken along. Keys are found without their values, so a value never hides
    /// the next key.
    static func keyedValues(_ s: String) -> String {
        guard let keys = try? NSRegularExpression(pattern: #"(["']?)([A-Za-z][A-Za-z0-9_.-]*)\1\s*[:=]\s*"#),
              let value = try? NSRegularExpression(pattern: #"(?:(?:[Bb]earer|[Bb]asic|[Tt]oken|[Dd]igest)\s+)?(?:"[^"]*"|'[^']*'|[^\s&;,}"']+)"#)
        else { return s }
        let ns = s as NSString
        var cuts: [NSRange] = []
        for m in keys.matches(in: s, range: NSRange(location: 0, length: ns.length)) where secret(ns.substring(with: m.range(at: 2))) {
            let from = m.range.location + m.range.length
            if let v = value.firstMatch(in: s, options: .anchored, range: NSRange(location: from, length: ns.length - from)), v.range.length > 0 {
                if let last = cuts.last, v.range.location < last.location + last.length {
                    cuts[cuts.count - 1] = NSUnionRange(last, v.range)
                } else {
                    cuts.append(v.range)
                }
            }
        }
        var out = s
        for r in cuts.reversed() {
            if let range = Range(r, in: out) { out.replaceSubrange(range, with: "…") }
        }
        return out
    }

    /// scheme://user:password@host, to the last @ so a password holding @ or / goes whole, and scheme://token@host.
    static func credentials(_ s: String) -> String {
        s.replacingOccurrences(of: #"([A-Za-z][A-Za-z0-9+.-]*://)[^\s@/]*:[^\s]*@"#, with: "$1…@", options: .regularExpression)
            .replacingOccurrences(of: #"([A-Za-z][A-Za-z0-9+.-]*://)[^/\s@…]+@"#, with: "$1…@", options: .regularExpression)
    }

    /// Runs of 24 or more letters, digits, _, - or + that hold both letters and digits: API keys, tokens, session ids.
    static func longRuns(_ s: String) -> String {
        guard let runs = try? NSRegularExpression(pattern: "[A-Za-z0-9_+-]{24,}") else { return s }
        var out = s
        for m in runs.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed() {
            guard let r = Range(m.range, in: out) else { continue }
            let run = out[r]
            if run.contains(where: \.isLetter), run.contains(where: \.isNumber) { out.replaceSubrange(r, with: "…") }
        }
        return out
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
