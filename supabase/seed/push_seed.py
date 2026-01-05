#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Dict, Iterable, List

from generate_seed import build_seed


def chunked(items: List[Dict[str, object]], size: int) -> Iterable[List[Dict[str, object]]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def post_rows(
    base_url: str,
    api_key: str,
    table: str,
    rows: List[Dict[str, object]],
    on_conflict: str,
    chunk_size: int = 200,
) -> int:
    if not rows:
        return 0

    base = base_url.rstrip("/") + f"/rest/v1/{table}"
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }

    total = 0
    for chunk in chunked(rows, chunk_size):
        params = urllib.parse.urlencode({"on_conflict": on_conflict})
        url = f"{base}?{params}"
        payload = json.dumps(chunk).encode("utf-8")
        request = urllib.request.Request(url, data=payload, method="POST")
        for key, value in headers.items():
            request.add_header(key, value)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                if response.status >= 400:
                    raise RuntimeError(f"Insert failed for {table}: HTTP {response.status}")
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Insert failed for {table}: HTTP {exc.code} {details}") from exc
        total += len(chunk)

    return total


def require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required env var: {name}")
    return value


def main() -> int:
    base_url = require_env("SUPABASE_URL")
    api_key = require_env("SUPABASE_SERVICE_ROLE_KEY")

    seed = build_seed()

    counts = {}
    counts["tags"] = post_rows(base_url, api_key, "tags", seed["tags"], "id")
    counts["questions"] = post_rows(base_url, api_key, "questions", seed["questions"], "id")
    counts["question_options"] = post_rows(
        base_url, api_key, "question_options", seed["question_options"], "id"
    )
    counts["question_tags"] = post_rows(
        base_url, api_key, "question_tags", seed["question_tags"], "question_id,tag_id"
    )

    print(
        "Pushed seed rows: "
        + ", ".join(f"{table}={count}" for table, count in counts.items())
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
