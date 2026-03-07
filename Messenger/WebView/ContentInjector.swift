import Foundation
import WebKit

@MainActor
enum ContentInjector {
    static func loadCSS() -> String? {
        guard let url = Bundle.main.url(forResource: "facebook-cleanup", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return css
    }

    static func loadJS() -> String? {
        let files = ["facebook-cleanup", "notification-bridge"]
        var combined = ""

        for file in files {
            guard let url = Bundle.main.url(forResource: file, withExtension: "js"),
                  let js = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            combined += js + "\n"
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
