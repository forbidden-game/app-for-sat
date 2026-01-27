#!/usr/bin/env python3
"""Import College Board SAT/PSAT practice tests extracted from PDFs.

This importer is designed for the JSON produced by the extractor in /Users/fg/work/justwater:
- Per test: `*.questions.json` (array of question objects)
- Optional index: `index.json` (not required)

Goals:
- Idempotent imports (stable UUIDs)
- Fixed banks per test/module (RW m1/m2, Math m1/m2)
- Numeric questions support multiple accepted answers via answer_key.accepted

Required env vars:
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

Usage example:
  SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
    python supabase/seed/import_satpdf.py --input-dir /Users/fg/work/justwater/out/all
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from typing import Any, Dict, Iterable, List, Optional, Tuple


def stable_uuid(name: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, name))


def require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required env var: {name}")
    return value


def request_json(
    url: str,
    method: str,
    api_key: str,
    payload: Optional[bytes] = None,
    prefer: Optional[str] = None,
    retries: int = 3,
) -> Any:
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}",
        "Connection": "keep-alive",
    }
    if payload is not None:
        headers["Content-Type"] = "application/json"
    if prefer:
        headers["Prefer"] = prefer

    attempt = 0
    while True:
        attempt += 1
        request = urllib.request.Request(url, data=payload, method=method)
        for key, value in headers.items():
            request.add_header(key, value)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read()
                if not raw:
                    return None
                return json.loads(raw.decode("utf-8"))
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")
            if exc.code >= 500 and attempt <= retries:
                time.sleep(2 ** (attempt - 1))
                continue
            raise RuntimeError(f"HTTP {exc.code} for {url}: {details}") from exc
        except (urllib.error.URLError, TimeoutError, ConnectionError) as exc:
            if attempt <= retries:
                time.sleep(2 ** (attempt - 1))
                continue
            raise RuntimeError(f"Request failed for {url}: {exc}") from exc


def rest_url(base_url: str, table: str, params: Optional[Dict[str, str]] = None) -> str:
    base = base_url.rstrip("/") + f"/rest/v1/{table}"
    if not params:
        return base
    return base + "?" + urllib.parse.urlencode(params)


def chunked(items: List[Dict[str, Any]], size: int) -> Iterable[List[Dict[str, Any]]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def upsert_rows(
    base_url: str,
    api_key: str,
    table: str,
    rows: List[Dict[str, Any]],
    on_conflict: str,
    chunk_size: int = 200,
) -> int:
    if not rows:
        return 0

    prefer = "resolution=merge-duplicates,return=minimal"
    total = 0
    for chunk in chunked(rows, chunk_size):
        url = rest_url(base_url, table, {"on_conflict": on_conflict})
        payload = json.dumps(chunk).encode("utf-8")
        request_json(url, "POST", api_key, payload=payload, prefer=prefer)
        total += len(chunk)
    return total


def insert_rows(
    base_url: str,
    api_key: str,
    table: str,
    rows: List[Dict[str, Any]],
    chunk_size: int = 500,
) -> int:
    if not rows:
        return 0

    prefer = "return=minimal"
    total = 0
    for chunk in chunked(rows, chunk_size):
        url = rest_url(base_url, table)
        payload = json.dumps(chunk).encode("utf-8")
        request_json(url, "POST", api_key, payload=payload, prefer=prefer)
        total += len(chunk)
    return total


def delete_where(base_url: str, api_key: str, table: str, filters: Dict[str, str]) -> None:
    # PostgREST delete uses query params as filters.
    url = rest_url(base_url, table, filters)
    request_json(url, "DELETE", api_key)


def fetch_one(base_url: str, api_key: str, table: str, select: str, filters: Dict[str, str]) -> Optional[dict]:
    params = {"select": select, "limit": "1"}
    params.update(filters)
    url = rest_url(base_url, table, params)
    rows = request_json(url, "GET", api_key)
    if isinstance(rows, list) and rows:
        return rows[0]
    return None


def parse_family(test_id: str) -> Tuple[str, int, str, int]:
    """Return (prefix, pt_number, display_name, sort_base)."""

    m = re.fullmatch(r"sat-practice-test-(\d+)", test_id)
    if m:
        n = int(m.group(1))
        return ("sat", n, f"SAT Practice Test {n}", 1000)

    m = re.fullmatch(r"psat-10-practice-test-(\d+)", test_id)
    if m:
        n = int(m.group(1))
        return ("psat10", n, f"PSAT 10 Practice Test {n}", 2000)

    m = re.fullmatch(r"psat-nmsqt-practice-test-(\d+)", test_id)
    if m:
        n = int(m.group(1))
        return ("psatnmsqt", n, f"PSAT/NMSQT Practice Test {n}", 3000)

    m = re.fullmatch(r"psat-8-9-practice-test-(\d+)", test_id)
    if m:
        n = int(m.group(1))
        return ("psat89", n, f"PSAT 8/9 Practice Test {n}", 4000)

    raise RuntimeError(f"Unknown test_id format: {test_id}")


def bank_key(section: str, module_num: int) -> Tuple[str, str, str, int]:
    """Return (slug_suffix, display_suffix, subject, sort_offset)."""

    if section == "Reading and Writing":
        return (f"rw-m{module_num}", f"R&W M{module_num}", "reading", module_num)
    if section == "Math":
        # place math after rw in ordering
        return (f"math-m{module_num}", f"Math M{module_num}", "math", 2 + module_num)
    raise RuntimeError(f"Unknown section: {section}")


def parse_numeric_value(raw: str) -> Optional[float]:
    s = str(raw).strip()
    if not s:
        return None
    # fraction like "361/8"
    m = re.fullmatch(r"([+-]?\d+)\s*/\s*([+-]?\d+)", s)
    if m:
        num = int(m.group(1))
        den = int(m.group(2))
        if den == 0:
            return None
        return num / den
    # plain number
    try:
        v = float(s)
        return v if v == v and v not in (float("inf"), float("-inf")) else None
    except Exception:
        return None


def infer_question_type(row: dict) -> str:
    """Infer MCQ vs SPR from content.

    We prefer robustness over trusting upstream labels, since PDF extraction can occasionally
    misclassify questions.
    """

    correct = row.get("correct_answer")
    if isinstance(correct, str) and re.fullmatch(r"[A-D]", correct.strip()):
        return "MCQ"

    choices = row.get("choices")
    if isinstance(choices, list) and len(choices) >= 2:
        labels = [str(c.get("label") or "").strip() for c in choices if isinstance(c, dict)]
        if any(re.fullmatch(r"[A-D]", lab) for lab in labels):
            return "MCQ"

    return "SPR"


def build_answer_key(question_type: str, correct_answer: Any) -> Dict[str, Any]:
    if question_type == "MCQ":
        if not isinstance(correct_answer, str) or not correct_answer.strip():
            raise RuntimeError(f"Invalid MCQ correct_answer: {correct_answer!r}")
        return {"correct": correct_answer.strip()}

    # SPR -> numeric
    accepted_raw: List[Any]
    if isinstance(correct_answer, list):
        accepted_raw = correct_answer
    else:
        accepted_raw = [correct_answer]

    accepted: List[float] = []
    for item in accepted_raw:
        v = parse_numeric_value(item)
        if v is not None:
            accepted.append(v)

    # de-dup while preserving order
    seen = set()
    accepted_unique: List[float] = []
    for v in accepted:
        key = f"{v:.12g}"
        if key in seen:
            continue
        seen.add(key)
        accepted_unique.append(v)

    if not accepted_unique:
        raise RuntimeError(f"Invalid numeric correct_answer: {correct_answer!r}")

    # Use the first accepted value as the backwards-compatible single correct value.
    return {"correct": accepted_unique[0], "accepted": accepted_unique}


def build_question_rows(questions: List[dict]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    q_rows: List[Dict[str, Any]] = []
    opt_rows: List[Dict[str, Any]] = []

    for q in questions:
        external_id = q["id"]
        qid = stable_uuid(f"satpdf:question:{external_id}")

        sec = q.get("section")
        mod_num = int(q.get("module"))
        extracted_type = q.get("question_type")
        qtype = infer_question_type(q)
        if extracted_type and extracted_type != qtype:
            # Keep the upstream label in metadata for debugging.
            pass

        _slug_suffix, _disp_suffix, subject, _off = bank_key(sec, mod_num)
        module_str = ("rw" if subject == "reading" else "math") + f"_m{mod_num}"

        answer_key = build_answer_key(qtype, q.get("correct_answer"))

        metadata = {
            "source": "collegeboard_pdf",
            "external_id": external_id,
            "test_id": q.get("test_id"),
            "section": sec,
            "dsat_module": mod_num,
            "question_number": q.get("question_number"),
            "pages": q.get("source", {}).get("pages", []),
            "zip_path": q.get("source", {}).get("zip_path"),
            "questions_pdf": q.get("source", {}).get("questions_pdf"),
            "scoring_pdf": q.get("source", {}).get("scoring_pdf"),
            "extracted_question_type": extracted_type,
            "import_version": 1,
        }

        q_rows.append(
            {
                "id": qid,
                "subject": subject,
                "module": module_str,
                "difficulty": 2,
                "question_type": "mcq" if qtype == "MCQ" else "numeric",
                "stem": q.get("question_text") or "",
                "answer_key": answer_key,
                "metadata": metadata,
            }
        )

        if qtype == "MCQ":
            for opt in q.get("choices", []) or []:
                label = str(opt.get("label") or "").strip()
                content = str(opt.get("text") or "").strip()
                if not label or not content:
                    continue
                oid = stable_uuid(f"satpdf:option:{qid}:{label}")
                opt_rows.append(
                    {
                        "id": oid,
                        "question_id": qid,
                        "label": label,
                        "content": content,
                    }
                )

    return q_rows, opt_rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input-dir", required=True, help="Directory containing *.questions.json")
    ap.add_argument("--only-test", default=None, help="Only import this test_id")
    ap.add_argument("--dry-run", action="store_true", help="Do not write to Supabase")
    args = ap.parse_args()

    base_url = require_env("SUPABASE_URL")
    api_key = require_env("SUPABASE_SERVICE_ROLE_KEY")

    files = sorted(glob.glob(os.path.join(args.input_dir, "*.questions.json")))
    if not files:
        raise RuntimeError(f"No *.questions.json found in: {args.input_dir}")

    for path in files:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not data:
            continue

        test_id = data[0].get("test_id")
        if not test_id:
            raise RuntimeError(f"Missing test_id in {path}")
        if args.only_test and args.only_test != test_id:
            continue

        prefix, pt, display, sort_base = parse_family(test_id)

        groups: Dict[Tuple[str, int], List[dict]] = {}
        for q in data:
            key = (q.get("section"), int(q.get("module")))
            groups.setdefault(key, []).append(q)

        # Deterministic ordering inside each group by question_number.
        for k in list(groups.keys()):
            groups[k] = sorted(groups[k], key=lambda x: int(x.get("question_number")))

        for (section, mod_num), questions in sorted(groups.items(), key=lambda it: (it[0][0], it[0][1])):
            slug_suffix, disp_suffix, _subject, sort_off = bank_key(section, mod_num)
            slug = f"{prefix}-pt{pt}-{slug_suffix}"
            title = f"{display} - {disp_suffix}"
            subtitle = f"{len(questions)} questions - College Board PDF"
            question_limit = len(questions)

            if args.dry_run:
                bank_id = stable_uuid(f"satpdf:bank:{slug}")
            else:
                # Fetch existing bank id by slug (avoid attempting to update primary key via upsert).
                existing = fetch_one(
                    base_url,
                    api_key,
                    "question_banks",
                    "id,slug",
                    {"slug": f"eq.{slug}"},
                )
                if existing and existing.get("id"):
                    bank_id = existing["id"]
                else:
                    bank_id = stable_uuid(f"satpdf:bank:{slug}")

            bank_row = {
                "id": bank_id,
                "slug": slug,
                "title": title,
                "subtitle": subtitle,
                "icon": None,
                "mode": "fixed",
                "question_limit": question_limit,
                "rule_json": {},
                "is_active": True,
                "sort_order": sort_base + pt * 10 + sort_off,
            }

            print(f"Import bank {slug} ({len(questions)} questions)")

            q_rows, opt_rows = build_question_rows(questions)

            qbq_rows: List[Dict[str, Any]] = []
            for q in questions:
                q_uuid = stable_uuid(f"satpdf:question:{q['id']}")
                qbq_rows.append(
                    {
                        "bank_id": bank_id,
                        "question_id": q_uuid,
                        "position": int(q.get("question_number")),
                    }
                )

            if args.dry_run:
                continue

            # Upsert bank, questions, options.
            upsert_rows(base_url, api_key, "question_banks", [bank_row], on_conflict="slug")
            upsert_rows(base_url, api_key, "questions", q_rows, on_conflict="id")
            upsert_rows(base_url, api_key, "question_options", opt_rows, on_conflict="id")

            # Reset bank membership and insert in correct order.
            delete_where(base_url, api_key, "question_bank_questions", {"bank_id": f"eq.{bank_id}"})
            insert_rows(base_url, api_key, "question_bank_questions", qbq_rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
