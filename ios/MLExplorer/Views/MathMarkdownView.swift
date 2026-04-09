import SwiftUI
import WebKit

/// Renders markdown + LaTeX math using marked.js + KaTeX in a WKWebView.
struct MathMarkdownView: UIViewRepresentable {
    let markdown: String
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Must set a real HTTPS baseURL so WKWebView allows CDN requests
        webView.loadHTMLString(html, baseURL: URL(string: "https://huangrui199126.github.io"))
    }

    // MARK: - HTML

    private var html: String {
        let isDark = colorScheme == .dark
        let fg      = isDark ? "#F2F2F7"              : "#1C1C1E"
        let bg      = isDark ? "#1C1C1E"              : "#FFFFFF"
        let codeBg  = isDark ? "rgba(255,255,255,.1)" : "rgba(0,0,0,.06)"
        let blockBg = isDark ? "rgba(255,255,255,.05)": "rgba(0,0,0,.04)"
        let border  = isDark ? "rgba(255,255,255,.15)": "rgba(0,0,0,.12)"

        // Base64-encode the markdown so it survives embedding in a JS string
        let encoded = Data(markdown.utf8).base64EncodedString()

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <link rel="stylesheet"
              href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        <script src="https://cdn.jsdelivr.net/npm/marked@12.0.0/marked.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
        <style>
        * { box-sizing: border-box; }
        html, body {
            margin: 0; padding: 0;
            background: \(bg);
            color: \(fg);
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            font-size: 16px;
            line-height: 1.7;
            word-break: break-word;
        }
        #root { padding: 4px 16px 48px; }
        h1,h2,h3,h4 {
            font-size: 1em;
            font-weight: 700;
            margin: 16px 0 4px;
            line-height: 1.4;
        }
        h1 { font-size: 1.15em; }
        h2 { font-size: 1.05em; }
        p { margin: 8px 0; }
        strong { font-weight: 600; }
        em { font-style: italic; }
        code {
            font-family: "Menlo", "Courier New", monospace;
            font-size: 0.85em;
            background: \(codeBg);
            padding: 1px 5px;
            border-radius: 5px;
        }
        pre {
            background: \(blockBg);
            border: 1px solid \(border);
            border-radius: 10px;
            padding: 12px;
            overflow-x: auto;
            margin: 10px 0;
        }
        pre code {
            background: none;
            padding: 0;
            font-size: 0.82em;
        }
        ul, ol { padding-left: 22px; margin: 8px 0; }
        li { margin: 3px 0; }
        blockquote {
            border-left: 3px solid \(border);
            margin: 10px 0;
            padding: 4px 12px;
            color: \(isDark ? "#98989D" : "#6C6C70");
        }
        .katex-display {
            overflow-x: auto;
            overflow-y: hidden;
            margin: 12px 0;
        }
        .katex { font-size: 1.05em; }
        </style>
        </head>
        <body>
        <div id="root"></div>
        <script>
        (function() {
            // Decode base64 content
            var raw = atob("\(encoded)");
            // Render markdown
            var html = marked.parse(raw, { breaks: true, gfm: true });
            document.getElementById('root').innerHTML = html;
            // Render math
            renderMathInElement(document.getElementById('root'), {
                delimiters: [
                    { left: '$$', right: '$$', display: true },
                    { left: '$',  right: '$',  display: false }
                ],
                throwOnError: false
            });
        })();
        </script>
        </body>
        </html>
        """
    }
}
