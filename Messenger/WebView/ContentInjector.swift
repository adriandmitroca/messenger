import Foundation
import WebKit

@MainActor
enum ContentInjector {
    private static func loadFile(name: String, ext: String) -> String? {
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
