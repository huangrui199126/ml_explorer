import SwiftUI
import WebKit

struct SolutionTabView: View {
    let challenge: MLChallenge
    @StateObject private var svc = MLSolutionService()
    @State private var selectedLang = "python"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if svc.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading solution…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = svc.error {
                ContentUnavailableView(
                    "Solution Unavailable",
                    systemImage: "clock.badge.questionmark",
                    description: Text(err)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let sol = svc.solution {
                solutionContent(sol)
            }
        }
        .task { await svc.load(id: challenge.id) }
    }

    // MARK: - Solution Content

    @ViewBuilder
    private func solutionContent(_ sol: MLSolution) -> some View {
        let langs = sol.availableLanguages
        let current = langs.first(where: { $0.key == selectedLang }) ?? langs.first

        VStack(spacing: 0) {
            // Language chips
            if langs.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(langs, id: \.key) { item in
                            langChip(label: item.label, key: item.key)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(.secondarySystemGroupedBackground))
                Divider()
            }

            // Rendered solution
            if let c = current {
                SolutionWebView(
                    language: c.label,
                    code: c.solution.code,
                    explanation: c.solution.explanation,
                    keyLearnings: c.solution.keyLearnings,
                    colorScheme: colorScheme
                )
            }
        }
        .onAppear {
            if let first = langs.first { selectedLang = first.key }
        }
    }

    private func langChip(label: String, key: String) -> some View {
        Button { selectedLang = key } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(selectedLang == key ? .semibold : .regular)
                .foregroundStyle(selectedLang == key ? Color.indigo : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    selectedLang == key
                        ? Color.indigo.opacity(0.12)
                        : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WebView renderer for solution

struct SolutionWebView: UIViewRepresentable {
    let language: String
    let code: String
    let explanation: String
    let keyLearnings: [String]
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.showsVerticalScrollIndicator = false
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        wv.loadHTMLString(html, baseURL: URL(string: "https://huangrui199126.github.io"))
    }

    private var html: String {
        let isDark  = colorScheme == .dark
        let fg      = isDark ? "#F2F2F7"              : "#1C1C1E"
        let bg      = isDark ? "#1C1C1E"              : "#FFFFFF"
        let codeBg  = isDark ? "#2C2C2E"              : "#F2F2F7"
        let hlTheme = isDark ? "atom-one-dark"        : "atom-one-light"

        let codeEncoded  = Data(code.utf8).base64EncodedString()
        let explEncoded  = Data(explanation.utf8).base64EncodedString()
        let langLC       = language.lowercased().replacingOccurrences(of: " ", with: "")
        let hlLang       = langLC == "numpy" ? "python" :
                           langLC == "tensorflow" ? "python" :
                           langLC == "pytorch" ? "python" : "python"

        let klHTML = keyLearnings.map { "<li>\($0)</li>" }.joined()

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
        <link rel="stylesheet"
              href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/\(hlTheme).min.css">
        <link rel="stylesheet"
              href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/python.min.js"></script>
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
            line-height: 1.65;
        }
        #root { padding: 16px 16px 48px; }
        .section-label {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: \(isDark ? "#98989D" : "#6C6C70");
            margin: 20px 0 8px;
        }
        pre {
            margin: 0;
            border-radius: 12px;
            overflow: hidden;
            background: \(codeBg) !important;
        }
        pre code.hljs {
            font-family: "Menlo","Courier New",monospace;
            font-size: 13px;
            line-height: 1.6;
            padding: 14px !important;
            border-radius: 12px;
            background: \(codeBg) !important;
        }
        .explanation p { margin: 6px 0; }
        .explanation strong { font-weight: 600; }
        ul.key-learnings {
            margin: 4px 0;
            padding-left: 20px;
        }
        ul.key-learnings li {
            margin: 6px 0;
            font-size: 15px;
        }
        .katex-display { overflow-x: auto; margin: 10px 0; }
        </style>
        </head>
        <body>
        <div id="root">
          <div class="section-label">\(language) Solution</div>
          <pre><code id="code-block" class="\(hlLang)"></code></pre>

          <div class="section-label">Explanation</div>
          <div class="explanation" id="explanation"></div>

          <div class="section-label">Key Learnings</div>
          <ul class="key-learnings">\(klHTML)</ul>
        </div>
        <script>
        (function() {
            // Inject code
            var code = atob("\(codeEncoded)");
            document.getElementById('code-block').textContent = code;
            hljs.highlightElement(document.getElementById('code-block'));

            // Inject explanation as markdown
            var expl = atob("\(explEncoded)");
            document.getElementById('explanation').innerHTML = marked.parse(expl, {breaks:true, gfm:true});

            // Render math in explanation
            renderMathInElement(document.getElementById('explanation'), {
                delimiters: [
                    {left:'$$',right:'$$',display:true},
                    {left:'$',right:'$',display:false}
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
