#!/usr/bin/env python3
"""Minimal, dependency-free Markdown -> self-contained HTML.
Handles the subset used by skill-scout reports: h1-h6, GFM pipe tables (with
:--: column alignment), blockquotes, ordered/unordered lists, hr, fenced code,
plus inline **bold**, `code`, and [links](url). Output is one static HTML file
with inlined CSS (no external requests) — safe to keep local / open in a browser.

Usage: md2html.py <input.md> <output.html> ["Title"]
"""
import sys, re, html

def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r'`([^`]+)`', lambda m: '<code>' + m.group(1) + '</code>', s)
    s = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    return s

def is_sep(cells):
    return cells and all(re.fullmatch(r':?-{2,}:?', c.strip()) for c in cells)

def align(c):
    c = c.strip()
    if c.startswith(':') and c.endswith(':'): return 'center'
    if c.endswith(':'): return 'right'
    return 'left'

def split_row(line):
    s = line.strip()
    if s.startswith('|'): s = s[1:]
    if s.endswith('|'): s = s[:-1]
    return [c.strip() for c in s.split('|')]

def convert(md):
    lines = md.split('\n')
    out, i, n = [], 0, len(lines)
    list_stack = None  # 'ul' or 'ol'
    def close_list():
        nonlocal list_stack
        if list_stack: out.append(f'</{list_stack}>'); list_stack = None
    while i < n:
        line = lines[i]
        # fenced code
        if line.strip().startswith('```'):
            close_list(); i += 1; buf = []
            while i < n and not lines[i].strip().startswith('```'):
                buf.append(html.escape(lines[i], quote=False)); i += 1
            i += 1
            out.append('<pre><code>' + '\n'.join(buf) + '</code></pre>'); continue
        # table
        if '|' in line and i + 1 < n and is_sep(split_row(lines[i+1])):
            close_list()
            header = split_row(line); aligns = [align(c) for c in split_row(lines[i+1])]
            out.append('<table><thead><tr>')
            for j, h in enumerate(header):
                a = aligns[j] if j < len(aligns) else 'left'
                out.append(f'<th style="text-align:{a}">{inline(h)}</th>')
            out.append('</tr></thead><tbody>')
            i += 2
            while i < n and '|' in lines[i] and lines[i].strip():
                cells = split_row(lines[i]); out.append('<tr>')
                for j, c in enumerate(cells):
                    a = aligns[j] if j < len(aligns) else 'left'
                    out.append(f'<td style="text-align:{a}">{inline(c)}</td>')
                out.append('</tr>'); i += 1
            out.append('</tbody></table>'); continue
        # headings
        m = re.match(r'(#{1,6})\s+(.*)', line)
        if m:
            close_list(); lvl = len(m.group(1))
            out.append(f'<h{lvl}>{inline(m.group(2))}</h{lvl}>'); i += 1; continue
        # hr
        if re.fullmatch(r'-{3,}', line.strip()):
            close_list(); out.append('<hr>'); i += 1; continue
        # blockquote (collapse consecutive)
        if line.strip().startswith('>'):
            close_list(); buf = []
            while i < n and lines[i].strip().startswith('>'):
                buf.append(inline(re.sub(r'^\s*>\s?', '', lines[i]))); i += 1
            out.append('<blockquote>' + '<br>'.join(buf) + '</blockquote>'); continue
        # unordered list
        m = re.match(r'\s*[-*]\s+(.*)', line)
        if m:
            if list_stack != 'ul': close_list(); out.append('<ul>'); list_stack = 'ul'
            out.append(f'<li>{inline(m.group(1))}</li>'); i += 1; continue
        # ordered list
        m = re.match(r'\s*\d+\.\s+(.*)', line)
        if m:
            if list_stack != 'ol': close_list(); out.append('<ol>'); list_stack = 'ol'
            out.append(f'<li>{inline(m.group(1))}</li>'); i += 1; continue
        # blank
        if not line.strip():
            close_list(); i += 1; continue
        # paragraph
        close_list(); out.append(f'<p>{inline(line)}</p>'); i += 1
    close_list()
    return '\n'.join(out)

CSS = """
:root { color-scheme: light dark; }
body { font-family: -apple-system, "Hiragino Kaku Gothic ProN", "Yu Gothic",
  Meiryo, sans-serif; line-height: 1.7; max-width: 960px; margin: 2rem auto;
  padding: 0 1.2rem; color: #1a1a1a; background: #fff; }
h1 { font-size: 1.7rem; border-bottom: 2px solid #ddd; padding-bottom: .3em; }
h2 { font-size: 1.3rem; margin-top: 2em; border-bottom: 1px solid #eee; padding-bottom: .2em; }
h3 { font-size: 1.1rem; margin-top: 1.6em; }
blockquote { border-left: 4px solid #c7c7c7; margin: 1em 0; padding: .3em 1em;
  background: #f7f7f7; color: #444; }
code { background: #f0f0f0; padding: .1em .35em; border-radius: 4px;
  font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: .9em; }
pre { background: #f6f8fa; padding: 1em; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; font-size: .92rem;
  display: block; overflow-x: auto; }
th, td { border: 1px solid #d0d7de; padding: .45em .7em; }
th { background: #f1f3f5; }
tbody tr:nth-child(even) { background: #fafbfc; }
hr { border: none; border-top: 1px solid #e0e0e0; margin: 2em 0; }
a { color: #0969da; }
ul, ol { padding-left: 1.4em; }
li { margin: .25em 0; }
@media (prefers-color-scheme: dark) {
  body { color: #e6e6e6; background: #0d1117; }
  h1,h2 { border-color: #30363d; } h3 { color: #e6e6e6; }
  blockquote { background: #161b22; border-color: #444c56; color: #c9d1d9; }
  code, pre { background: #161b22; } th { background: #161b22; }
  tbody tr:nth-child(even) { background: #11151a; }
  th, td { border-color: #30363d; } hr { border-color: #30363d; }
}
"""

def main():
    src, dst = sys.argv[1], sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else "Report"
    with open(src, encoding='utf-8') as f: md = f.read()
    body = convert(md)
    doc = (f'<!doctype html>\n<html lang="ja"><head><meta charset="utf-8">'
           f'<meta name="viewport" content="width=device-width, initial-scale=1">'
           f'<title>{html.escape(title)}</title><style>{CSS}</style></head>'
           f'<body>\n{body}\n</body></html>\n')
    with open(dst, 'w', encoding='utf-8') as f: f.write(doc)
    print(f"wrote {dst}")

if __name__ == '__main__':
    main()
