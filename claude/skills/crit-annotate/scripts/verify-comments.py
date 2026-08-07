#!/usr/bin/env python3
"""Check that a payload sent with `crit comment --json` actually landed on the page.

`crit comment` reports success for comments it stores but cannot draw — a deleted
file has no line on the new side, so the comment is counted while its anchor stays
empty and the reader never sees it. Counting replies is not enough either, so this
compares every payload entry against the stored review file and fails on:

  - an entry with no matching stored comment or reply
  - a stored comment whose anchor is empty (accepted, counted, never drawn)

Usage:
  verify-comments.py <session-id> [payload.json ...] [--root ~/.crit]

Exit status is 0 only when every entry landed and every anchor is non-empty.
"""

import argparse
import json
import os
import sys


def load_review(root, session):
    path = os.path.join(os.path.expanduser(root), "reviews", session, "review.json")
    if not os.path.exists(path):
        sys.exit(f"no review file at {path} — wrong session id, or no comment has been sent yet")
    with open(path) as f:
        return path, json.load(f)


def stored_comments(review):
    """Flatten the review file into (path, comment) pairs. A comment with no path is
    kept in the top-level review_comments, so walking files alone undercounts."""
    out = []
    for path, entry in review.get("files", {}).items():
        items = entry.get("comments", []) if isinstance(entry, dict) else entry
        for c in items:
            out.append((path, c))
    for c in review.get("review_comments", []):
        out.append((None, c))
    return out


def start_line(line):
    return int(str(line).split("-")[0])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("session")
    ap.add_argument("payloads", nargs="*")
    ap.add_argument("--root", default="~/.crit")
    args = ap.parse_args()

    review_path, review = load_review(args.root, args.session)
    pairs = stored_comments(review)

    print(f"review file: {review_path}")
    for path, c in pairs:
        anchor = " ".join(str(c.get("anchor", "")).split())[:60]
        where = f"{path}:{c.get('start_line')}" if path else "(review-level)"
        n_replies = len(c.get("replies", []))
        flag = "  <-- EMPTY ANCHOR" if path and not anchor else ""
        print(f"  {c.get('id')} {where} replies={n_replies} anchor={anchor!r}{flag}")
    print(f"stored: {len(pairs)} comments, {sum(len(c.get('replies', [])) for _, c in pairs)} replies")

    problems = [f"empty anchor on {p}:{c.get('start_line')} ({c.get('id')})"
                for p, c in pairs if p and not str(c.get("anchor", "")).strip()]

    for payload_path in args.payloads:
        with open(payload_path) as f:
            entries = json.load(f)
        for e in entries:
            body = e.get("body", "")
            if e.get("reply_to"):
                found = any(c.get("id") == e["reply_to"] and any(r.get("body") == body for r in c.get("replies", []))
                            for _, c in pairs)
                label = f"reply to {e['reply_to']}"
            elif e.get("path"):
                found = any(p == e["path"] and c.get("start_line") == start_line(e.get("line", 0)) and c.get("body") == body
                            for p, c in pairs)
                label = f"{e['path']}:{e.get('line')}"
            else:
                found = any(p is None and c.get("body") == body for p, c in pairs)
                label = "(review-level)"
            if not found:
                problems.append(f"not stored: {label} from {os.path.basename(payload_path)}")

    if problems:
        print("\nFAIL")
        for p in problems:
            print(f"  {p}")
        sys.exit(1)
    print("\nOK — every entry landed and every anchor is drawable")


if __name__ == "__main__":
    main()
