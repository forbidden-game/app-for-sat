#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import uuid
from typing import Any, Dict, Iterable, List, Optional, Tuple

OPEN_SAT_DATA_URL = "https://api.jsonsilo.com/public/942c3c3b-3a0c-4be3-81c2-12029def19f5"
OPEN_SAT_SOURCE_URL = "https://pinesat.com/api/questions"
OPEN_SAT_LICENSE = "OpenSAT database usage allowed per LICENSE.md"

DIFFICULTY_MAP = {
    "easy": 1,
    "medium": 2,
    "hard": 3,
}


def stable_uuid(name: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, name))


def clean_text(value: Any) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if text.lower() == "null":
        return ""
    return text


def sort_choice_labels(labels: Iterable[str]) -> List[str]:
    order = {chr(ord("A") + idx): idx for idx in range(26)}
    return sorted(labels, key=lambda label: (order.get(label.upper(), 999), label))


def resolve_api_url() -> str:
    return (
        os.getenv("SUPABASE_URL")
        or os.getenv("SUPABASE_API_URL")
        or "http://127.0.0.1:54321"
    )


def resolve_service_key() -> str:
    return (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_SERVICE_KEY")
        or os.getenv("SUPABASE_SECRET_KEY")
        or os.getenv("SERVICE_ROLE_KEY")
        or ""
    )


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


def fetch_dataset(url: str) -> Dict[str, Any]:
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def map_difficulty(label: str) -> int:
    if not label:
        return 2
    return DIFFICULTY_MAP.get(label.strip().lower(), 2)


def build_stem(paragraph: str, question: str) -> str:
    if paragraph and question:
        return f"{paragraph}\n\n{question}"
    return question or paragraph


def normalize_visuals(visuals: Any) -> Optional[Dict[str, Any]]:
    if not isinstance(visuals, dict):
        return None
    visual_type = clean_text(visuals.get("type"))
    svg_content = clean_text(visuals.get("svg_content"))
    if not visual_type and not svg_content:
        return None
    return {
        "type": visual_type,
        "svg_content": svg_content,
    }


def build_rows(
    data: Dict[str, Any],
    sections: List[str],
    limit: Optional[int],
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[Tuple[str, str]], Dict[str, int]]:
    questions: List[Dict[str, Any]] = []
    options: List[Dict[str, Any]] = []
    question_tags: List[Tuple[str, str]] = []
    fingerprint_set: set[str] = set()
    source_id_counts: Dict[str, int] = {}

    stats = {
        "total": 0,
        "skipped": 0,
    }

    for section in sections:
        items = data.get(section, [])
        for item in items:
            if limit is not None and len(questions) >= limit:
                return questions, options, question_tags, stats

            stats["total"] += 1
            source_id = clean_text(item.get("id"))
            domain = clean_text(item.get("domain"))
            difficulty_label = clean_text(item.get("difficulty"))
            difficulty = map_difficulty(difficulty_label)

            question_blob = item.get("question") or {}
            paragraph = clean_text(question_blob.get("paragraph"))
            question_text = clean_text(question_blob.get("question"))
            explanation = clean_text(question_blob.get("explanation"))
            correct_answer = clean_text(question_blob.get("correct_answer"))

            if not question_text or not correct_answer:
                stats["skipped"] += 1
                continue

            subject = "math" if section == "math" else "reading"
            module = domain or ("Math" if subject == "math" else "Reading")

            stem = build_stem(paragraph, question_text)

            choices = question_blob.get("choices") or {}
            normalized_choices = {label: clean_text(choices.get(label)) for label in sort_choice_labels(choices.keys())}
            fingerprint_payload = {
                "section": section,
                "domain": domain,
                "paragraph": paragraph,
                "question": question_text,
                "choices": normalized_choices,
                "correct": correct_answer,
            }
            fingerprint = json.dumps(fingerprint_payload, sort_keys=True, separators=(",", ":"))
            if fingerprint in fingerprint_set:
                stats["skipped"] += 1
                continue
            fingerprint_set.add(fingerprint)

            source_key = f"{section}:{source_id}" if source_id else ""
            source_id_counts[source_key] = source_id_counts.get(source_key, 0) + 1
            if source_id and source_id_counts[source_key] == 1:
                question_id_seed = f"{section}:{source_id}"
            elif source_id:
                question_id_seed = f"{section}:{source_id}:{fingerprint}"
            else:
                question_id_seed = fingerprint
            question_id = stable_uuid(f"opensat:question:{question_id_seed}")

            metadata: Dict[str, Any] = {
                "source": "OpenSAT",
                "source_url": OPEN_SAT_SOURCE_URL,
                "source_data_url": OPEN_SAT_DATA_URL,
                "source_id": source_id,
                "section": section,
                "domain": domain,
                "difficulty_label": difficulty_label,
                "license": OPEN_SAT_LICENSE,
            }
            if paragraph:
                metadata["paragraph"] = paragraph
            if explanation:
                metadata["explanation"] = explanation
            visuals = normalize_visuals(item.get("visuals"))
            if visuals:
                metadata["visuals"] = visuals

            questions.append(
                {
                    "id": question_id,
                    "subject": subject,
                    "module": module,
                    "difficulty": difficulty,
                    "question_type": "mcq",
                    "stem": stem,
                    "answer_key": {"correct": correct_answer},
                    "metadata": metadata,
                }
            )

            for label in sort_choice_labels(normalized_choices.keys()):
                content = clean_text(normalized_choices.get(label))
                if not content:
                    continue
                option_id = stable_uuid(f"opensat:option:{question_id}:{label}")
                options.append(
                    {
                        "id": option_id,
                        "question_id": question_id,
                        "label": label,
                        "content": content,
                    }
                )

            if domain:
                question_tags.append((question_id, domain))

    return questions, options, question_tags, stats


def get_tag_id(api_url: str, api_key: str, tag_name: str) -> Optional[str]:
    params = {
        "select": "id,name",
        "name": f"eq.{tag_name}",
    }
    url = f"{api_url.rstrip('/')}/rest/v1/tags?{urllib.parse.urlencode(params)}"
    data = request_json(url, "GET", api_key)
    if not data:
        return None
    return data[0]["id"]


def ensure_tag(api_url: str, api_key: str, tag_name: str, category: str) -> str:
    existing_id = get_tag_id(api_url, api_key, tag_name)
    if existing_id:
        return existing_id

    url = f"{api_url.rstrip('/')}/rest/v1/tags?{urllib.parse.urlencode({'on_conflict': 'name'})}"
    payload = json.dumps([
        {
            "name": tag_name,
            "category": category,
        }
    ]).encode("utf-8")

    created = request_json(
        url,
        "POST",
        api_key,
        payload=payload,
        prefer="resolution=merge-duplicates,return=representation",
    )
    if created:
        return created[0]["id"]

    existing_id = get_tag_id(api_url, api_key, tag_name)
    if existing_id:
        return existing_id

    raise RuntimeError(f"Failed to create tag: {tag_name}")


def chunked(items: List[Dict[str, Any]], size: int) -> Iterable[List[Dict[str, Any]]]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def post_rows(
    api_url: str,
    api_key: str,
    table: str,
    rows: List[Dict[str, Any]],
    on_conflict: str,
    batch_size: int,
) -> int:
    if not rows:
        return 0

    params = urllib.parse.urlencode({"on_conflict": on_conflict})
    url = f"{api_url.rstrip('/')}/rest/v1/{table}?{params}"
    total = 0

    for chunk in chunked(rows, batch_size):
        payload = json.dumps(chunk, separators=(",", ":")).encode("utf-8")
        request_json(
            url,
            "POST",
            api_key,
            payload=payload,
            prefer="resolution=merge-duplicates,return=minimal",
        )
        total += len(chunk)

    return total


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import OpenSAT questions into Supabase.")
    parser.add_argument(
        "--data-url",
        default=OPEN_SAT_DATA_URL,
        help="OpenSAT JSON dataset URL.",
    )
    parser.add_argument(
        "--api-url",
        default=None,
        help="Supabase API URL (defaults to SUPABASE_URL or localhost).",
    )
    parser.add_argument(
        "--service-key",
        default=None,
        help="Supabase service role key (defaults to SUPABASE_SERVICE_ROLE_KEY).",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=200,
        help="Batch size for inserts.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Limit total questions imported (for testing).",
    )
    parser.add_argument(
        "--section",
        action="append",
        choices=["math", "english"],
        help="Restrict to a specific section (repeatable).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Build payload but skip inserts.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    api_url = args.api_url or resolve_api_url()
    service_key = args.service_key or resolve_service_key()
    if not service_key:
        print("Missing SUPABASE_SERVICE_ROLE_KEY (or --service-key).", file=sys.stderr)
        return 1

    sections = args.section or ["math", "english"]

    data = fetch_dataset(args.data_url)
    questions, options, question_tags, stats = build_rows(data, sections, args.limit)

    tag_names = sorted({tag_name for _, tag_name in question_tags})
    tag_name_to_id: Dict[str, str] = {}
    for tag_name in tag_names:
        tag_id = ensure_tag(api_url, service_key, tag_name, "domain")
        tag_name_to_id[tag_name] = tag_id

    question_tag_rows = [
        {"question_id": qid, "tag_id": tag_name_to_id[tag_name]}
        for qid, tag_name in question_tags
    ]

    print(
        "Prepared OpenSAT import: "
        f"questions={len(questions)}, options={len(options)}, tags={len(tag_name_to_id)}, "
        f"question_tags={len(question_tag_rows)}, skipped={stats['skipped']}"
    )

    if args.dry_run:
        print("Dry run enabled; no inserts executed.")
        return 0

    inserted_tags = len(tag_name_to_id)
    inserted_questions = post_rows(
        api_url,
        service_key,
        "questions",
        questions,
        "id",
        args.batch_size,
    )
    inserted_options = post_rows(
        api_url,
        service_key,
        "question_options",
        options,
        "id",
        args.batch_size,
    )
    inserted_question_tags = post_rows(
        api_url,
        service_key,
        "question_tags",
        question_tag_rows,
        "question_id,tag_id",
        args.batch_size,
    )

    print(
        "Import complete: "
        f"questions={inserted_questions}, options={inserted_options}, "
        f"tags={inserted_tags}, question_tags={inserted_question_tags}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
