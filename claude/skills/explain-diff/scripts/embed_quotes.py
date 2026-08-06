#!/usr/bin/env python3
"""Fill (or check) the code quotes in an explainer page from their source files.

The writer never types a quote. It leaves an empty element naming a file and the
line ranges it wants:

    <pre data-quote="claude/hooks/before-git.sh" data-lines="25-26,33-34"></pre>

and this script fills in the exact lines, HTML-escaped, inserting an elision
marker carrying the real count of the lines it skipped. Quoting is therefore a
lookup rather than a regeneration, which is the only way the two failures
measured on this skill — non-contiguous lines joined as if adjacent, and an
elision count written from memory — stop being possible.

    embed_quotes.py PAGE --root DIR [--rev REV] [--check]

--check recomputes every quote and reports the ones that no longer match, so the
verifier can prove the page still says what the files say.
"""

import argparse
import html
import re
import subprocess
import sys

QUOTE_TAG = re.compile(r"<pre\b([^>]*\bdata-quote=[^>]*)>(.*?)</pre>", re.DOTALL)
ATTR = re.compile(r'(\w[\w-]*)\s*=\s*"([^"]*)"')
# Authoring notes in the scaffold are addressed to the writer, not the reader.
# They are marked so they can be dropped from the delivered page mechanically,
# rather than asked for in a rule the writer has to remember.
SCAFFOLD_NOTE = re.compile(r"[ \t]*<!--\s*SCAFFOLD\b.*?-->\n?", re.DOTALL)


def source_lines(path, root, rev):
    """The file's lines, from the given revision or from the working tree."""
    if rev:
        out = subprocess.run(
            ["git", "-C", root, "show", f"{rev}:{path}"],
            capture_output=True, text=True,
        )
        if out.returncode != 0:
            raise LookupError(f"git show {rev}:{path} failed: {out.stderr.strip()}")
        return out.stdout.splitlines()
    try:
        with open(f"{root}/{path}", encoding="utf-8") as handle:
            return handle.read().splitlines()
    except OSError as err:
        raise LookupError(f"cannot read {path}: {err}") from err


def parse_ranges(spec, total, path):
    ranges = []
    for chunk in spec.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        if "-" in chunk:
            first, last = chunk.split("-", 1)
        else:
            first = last = chunk
        try:
            start, end = int(first), int(last)
        except ValueError:
            raise LookupError(f"{path}: cannot read line range {chunk!r}") from None
        if start < 1 or end < start:
            raise LookupError(f"{path}: line range {chunk!r} is not a range")
        if end > total:
            raise LookupError(f"{path}: line range {chunk!r} runs past the file ({total} lines)")
        ranges.append((start, end))
    if not ranges:
        raise LookupError(f"{path}: no line ranges given")
    ranges.sort()
    return ranges


def render(path, root, rev, spec):
    lines = source_lines(path, root, rev)
    ranges = parse_ranges(spec, len(lines), path)
    parts = []
    previous_end = None
    for start, end in ranges:
        if previous_end is not None:
            skipped = start - previous_end - 1
            if skipped > 0:
                parts.append(
                    f'<span class="cmt"># …（{skipped} 行省略）</span>'
                )
        body = "\n".join(html.escape(line) for line in lines[start - 1:end])
        parts.append(body)
        previous_end = end
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("page")
    parser.add_argument("--root", required=True, help="repository or checkout the paths are relative to")
    parser.add_argument("--rev", help="read files at this revision instead of the working tree")
    parser.add_argument("--check", action="store_true", help="report mismatches instead of writing")
    args = parser.parse_args()

    with open(args.page, encoding="utf-8") as handle:
        original = handle.read()

    # Drop the authoring notes before looking for quotes: they carry an example
    # quote element, and matching inside a comment would try to resolve it.
    page = SCAFFOLD_NOTE.sub("", original)

    problems = []
    filled = [0]

    def replace(match):
        attrs = dict(ATTR.findall(match.group(1)))
        path = attrs.get("data-quote", "")
        spec = attrs.get("data-lines", "")
        rev = attrs.get("data-rev") or args.rev
        try:
            body = render(path, args.root, rev, spec)
        except LookupError as err:
            problems.append(str(err))
            return match.group(0)
        if args.check:
            if match.group(2).strip("\n") != body:
                problems.append(
                    f"{path} lines {spec}: the page does not match the file"
                )
            return match.group(0)
        filled[0] += 1
        return f"<pre{match.group(1)}>\n{body}\n</pre>"

    rewritten = QUOTE_TAG.sub(replace, page)

    if problems:
        for problem in problems:
            print(f"MISMATCH: {problem}", file=sys.stderr)
        return 1

    if args.check:
        print("every quote matches its source file")
        return 0

    if rewritten != original:
        with open(args.page, "w", encoding="utf-8") as handle:
            handle.write(rewritten)
    print(f"filled {filled[0]} quote block(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
