import Foundation
import WebKit

@MainActor
enum ContentInjector {
    #if DEBUG
    private static let sourceRoot: String? = {
        // Walk up from the bundle to find the project source directory
        var url = Bundle.main.bundleURL
        for _ in 0..<5 {
            url = url.deletingLastPathComponent()
            let candidate = url.appendingPathComponent("Messenger/Injection")
            if FileManager.default.fileExists(atPath: candidate.path) {
                print("[Messenger] Hot reload from: \(candidate.path)")
                return candidate.path
            }
        }
        return nil
    }()
    #endif

    private static func loadFile(name: String, ext: String) -> String? {
        #if DEBUG
        if let root = sourceRoot {
            let path = "\(root)/\(name).\(ext)"
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                return content
            }
        }
        #endif
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return content
    }

    static func loadCSS() -> String? {
        loadFile(name: "facebook-cleanup", ext: "css")?
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
    }

    static func loadJS() -> String? {
        let files = ["facebook-cleanup", "notification-bridge"]
        var combined = ""
        for file in files {
            if let js = loadFile(name: file, ext: "js") {
                combined += js + "\n"
            }
        }
        return combined.isEmpty ? nil : combined
    }

    static func injectScripts(into contentController: WKUserContentController) {
        if let css = loadCSS() {
            let earlyCSS = WKUserScript(
                source: """
                    var style = document.createElement('style');
                    style.textContent = `\(css)`;
                    (document.head || document.documentElement).appendChild(style);
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            contentController.addUserScript(earlyCSS)

            let lateCSS = WKUserScript(
                source: """
                    var style = document.createElement('style');
                    style.textContent = `\(css)`;
                    document.head.appendChild(style);
                """,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            contentController.addUserScript(lateCSS)
        }

        if let js = loadJS() {
            let jsScript = WKUserScript(
                source: js,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            contentController.addUserScript(jsScript)
        }
    }
}
