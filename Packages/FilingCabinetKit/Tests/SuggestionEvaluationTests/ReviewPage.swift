import Foundation

/// The page Ben opens from Finder to judge the model's titles: one self-contained HTML file (inline style and script,
/// images as data URIs, no network). Titles are labelled "A", "B" in a per-case shuffled order so he can't tell which
/// style made which; the label to style mapping lives only in a JSON block the script reads, and the downloaded
/// `judgements.json` carries the style as each judgement's `variant`.
enum ReviewPage {
    struct Entry {
        let item: EvaluationCase
        let isPrivate: Bool
        /// Page 1 as JPEG.
        let image: Data
        /// The collection the model suggested, if it did.
        let collectionID: String?
        /// One per title style, in any order; nil where the model gave none.
        let titles: [(style: String, title: String?)]
    }

    struct Labelled {
        let label: String
        let style: String
        let title: String?
    }

    private static let builtInCollections = ["wallet", "receipts", "notes", "documents", "throwaways"]

    static func html(for entries: [Entry]) -> String {
        let rows = entries.map(row).joined(separator: "\n")
        return """
            <!doctype html>
            <html lang="en"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Suggestion review</title>
            <style>\(css)</style></head>
            <body>
            <header><h1>Suggestion review</h1>
            <p><span id="count">0</span> of \(entries.count) judged. Tick or cross each title, say what you would call the scan,
            and download your answers when you are done. Answers are kept in this browser too.</p>
            <button id="download" type="button">Download answers</button></header>
            <main>
            \(rows)
            </main>
            <script type="application/json" id="variants">\(variantsJSON(entries))</script>
            <script>\(script)</script>
            </body></html>
            """
    }

    /// Labels for a case's titles in a shuffled order: seeded by the case id, so the same case always comes out the same.
    static func labelled(_ entry: Entry) -> [Labelled] {
        let shuffled = entry.titles.sorted { seed(entry.item.id + $0.style) < seed(entry.item.id + $1.style) }
        return shuffled.enumerated().map {
            Labelled(
                label: String(UnicodeScalar(UInt8(65 + $0.offset))), style: $0.element.style, title: $0.element.title)
        }
    }

    /// FNV-1a: stable across runs, unlike `hashValue`.
    private static func seed(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    private struct Variant: Encodable {
        let style: String
        let title: String
    }

    private static func variantsJSON(_ entries: [Entry]) -> String {
        var all: [String: [String: Variant]] = [:]
        for entry in entries {
            all[entry.item.id] = Dictionary(
                uniqueKeysWithValues: labelled(entry).map {
                    ($0.label, Variant(style: $0.style, title: $0.title ?? ""))
                })
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]  // escapes "/", so "</script>" can't end the block early
        // try? is safe: a [String: Variant] always encodes; "{}" only keeps the page valid.
        return (try? encoder.encode(all)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "{}"
    }

    private static func row(_ entry: Entry) -> String {
        let id = escape(entry.item.id)
        let titles = labelled(entry).map { labelled in
            let (label, title) = (labelled.label, labelled.title)
            guard let title else {
                return
                    "<div class=\"title\" data-label=\"\(label)\"><b>\(label)</b><span class=\"none\">no suggestion</span></div>"
            }
            return """
                <div class="title" data-label="\(label)"><b>\(label)</b><span class="text">\(escape(title))</span>\
                <button type="button" class="yes" data-verdict="yes" aria-label="Right">✓</button>\
                <button type="button" class="no" data-verdict="no" aria-label="Wrong">✗</button></div>
                """
        }.joined(separator: "\n")
        let picker = entry.isPrivate ? collectionPicker(entry) : ""
        return """
            <section class="case" data-id="\(id)">
            <img src="data:image/jpeg;base64,\(entry.image.base64EncodedString())" alt="Scan \(id)">
            <div class="answers"><h2>\(id)</h2>
            \(titles)
            <label>What I'd call it <input type="text" class="better" autocomplete="off"></label>
            \(picker)
            </div></section>
            """
    }

    private static func collectionPicker(_ entry: Entry) -> String {
        let ids = entry.item.collections ?? builtInCollections
        let tags =
            (["<option value=\"\">Not set</option>"]
            + ids.map { "<option value=\"\(escape($0))\">\(escape($0))</option>" })
            .joined()
        let said = entry.collectionID.map { " (suggested: \(escape($0)))" } ?? ""
        return "<label>Collection\(said) <select class=\"collection\">\(tags)</select></label>"
    }

    private static func escape(_ text: String) -> String {
        text.replacing("&", with: "&amp;").replacing("<", with: "&lt;").replacing(">", with: "&gt;")
            .replacing("\"", with: "&quot;").replacing("'", with: "&#39;")
    }

    private static let css = """
        :root { color-scheme: light dark; --bg: #fff; --fg: #1c1c1e; --muted: #6c6c70; --line: #d8d8dc; --card: #f5f5f7; \
        --yes: #1f8a43; --no: #c62828; }
        @media (prefers-color-scheme: dark) { :root { --bg: #111113; --fg: #f2f2f7; --muted: #9a9aa0; --line: #38383d; \
        --card: #1c1c1f; --yes: #4cc573; --no: #ff6b6b; } }
        body { background: var(--bg); color: var(--fg); font: 16px/1.4 -apple-system, system-ui, sans-serif; margin: 0; \
        padding: 16px; max-width: 820px; margin-inline: auto; }
        header { position: sticky; top: 0; background: var(--bg); padding-bottom: 8px; border-bottom: 1px solid var(--line); }
        h1 { font-size: 1.3rem; margin: 0 0 4px; } h2 { font-size: 1rem; margin: 0 0 8px; color: var(--muted); }
        .case { display: flex; gap: 16px; flex-wrap: wrap; background: var(--card); border: 1px solid var(--line); \
        border-radius: 10px; padding: 12px; margin: 16px 0; }
        .case.done { border-color: var(--yes); }
        .case img { width: 360px; max-width: 100%; height: auto; align-self: flex-start; cursor: zoom-in; }
        .case img.big { width: 100%; cursor: zoom-out; }
        .answers { flex: 1; min-width: 240px; display: flex; flex-direction: column; gap: 8px; }
        .title { display: flex; align-items: center; gap: 8px; } .title b { width: 1.4em; color: var(--muted); }
        .title .text { flex: 1; } .none { color: var(--muted); font-style: italic; }
        button { font: inherit; border: 1px solid var(--line); background: var(--bg); color: var(--fg); \
        border-radius: 8px; padding: 4px 12px; cursor: pointer; }
        .title button.on.yes { background: var(--yes); color: #fff; border-color: var(--yes); }
        .title button.on.no { background: var(--no); color: #fff; border-color: var(--no); }
        label { display: flex; flex-direction: column; gap: 4px; color: var(--muted); font-size: 0.9rem; }
        input, select { font: inherit; padding: 6px; border-radius: 8px; border: 1px solid var(--line); \
        background: var(--bg); color: var(--fg); }
        """

    private static let script = """
        const variants = JSON.parse(document.getElementById('variants').textContent);
        const KEY = 'fc-eval-answers';
        let answers = {};
        try { answers = JSON.parse(localStorage.getItem(KEY) || '{}'); } catch (e) { answers = {}; }
        const save = () => { try { localStorage.setItem(KEY, JSON.stringify(answers)); } catch (e) {} };
        const mine = id => (answers[id] = answers[id] || { verdicts: {}, better: '', collection: '' });
        const isJudged = a => a && (Object.keys(a.verdicts).length > 0 || a.better.trim() !== '' || a.collection !== '');
        function refresh() {
          let n = 0;
          document.querySelectorAll('.case').forEach(section => {
            const a = answers[section.dataset.id];
            section.querySelectorAll('.title').forEach(row => {
              row.querySelectorAll('button').forEach(b => {
                b.classList.toggle('on', !!a && a.verdicts[row.dataset.label] === b.dataset.verdict);
              });
            });
            const done = isJudged(a);
            section.classList.toggle('done', done);
            if (done) n++;
          });
          document.getElementById('count').textContent = n;
        }
        document.querySelectorAll('.case').forEach(section => {
          const id = section.dataset.id, a = answers[id];
          if (a) {
            section.querySelector('.better').value = a.better;
            const pick = section.querySelector('.collection');
            if (pick) pick.value = a.collection;
          }
          section.querySelector('img').addEventListener('click', e => e.target.classList.toggle('big'));
          section.querySelectorAll('.title button').forEach(b => b.addEventListener('click', () => {
            const v = mine(id).verdicts, label = b.closest('.title').dataset.label;
            if (v[label] === b.dataset.verdict) delete v[label]; else v[label] = b.dataset.verdict;
            save(); refresh();
          }));
          section.querySelector('.better').addEventListener('input', e => { mine(id).better = e.target.value; save(); refresh(); });
          const pick = section.querySelector('.collection');
          if (pick) pick.addEventListener('change', () => { mine(id).collection = pick.value; save(); refresh(); });
        });
        document.getElementById('download').addEventListener('click', () => {
          const out = [];
          for (const id of Object.keys(answers)) {
            const a = answers[id];
            if (!isJudged(a)) continue;
            const better = a.better.trim() || null, collection = a.collection || null;
            const labels = Object.keys(a.verdicts);
            // Nothing ticked: a "no" on an empty title carries the typed title or collection and removes nothing.
            if (labels.length === 0) {
              const first = Object.keys(variants[id] || {}).sort()[0];
              if (first) out.push({ id, variant: variants[id][first].style, title: '', verdict: 'no', better, collection });
            }
            labels.forEach(label => out.push({ id, variant: variants[id][label].style, title: variants[id][label].title,
              verdict: a.verdicts[label], better, collection }));
          }
          const link = document.createElement('a');
          link.href = URL.createObjectURL(new Blob([JSON.stringify(out, null, 2)], { type: 'application/json' }));
          link.download = 'judgements.json';
          document.body.appendChild(link); link.click(); link.remove();
        });
        refresh();
        """
}
