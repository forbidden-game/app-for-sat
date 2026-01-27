# SAT/PSAT (College Board PDF) Import

This project stores questions in Supabase Postgres and serves them to iOS via the `start_practice_session` RPC.

This document defines the import contract for the College Board PDF-derived SAT/PSAT dataset.

## What We Import

Input files come from the PDF extractor repo and look like:

- `*.questions.json` (one per test)
- `index.json` (optional)

Each question includes:

- `id` (stable external id like `sat-practice-test-4:rw:m1:q1`)
- `section` (`Reading and Writing` or `Math`)
- `module` (`1` or `2` in DSAT meaning)
- `question_type` (`MCQ` or `SPR`)
- `question_text` (prompt)
- `choices[]` (for MCQ)
- `correct_answer` (string for MCQ, string or list for SPR)
- `source.pages` (for PDF audit)

## Mapping To Supabase Schema

Tables:

- `public.questions`
- `public.question_options`
- `public.question_banks` (fixed banks)
- `public.question_bank_questions`

### questions

- `question_type`:
  - `MCQ` -> `mcq`
  - `SPR` -> `numeric`
- `subject`:
  - Reading & Writing -> `reading`
  - Math -> `math`

Note: iOS uses `question.subject == "reading"` to decide if grammar analysis UI is shown.

- `module`:
  - stored as a stable filter key (not the DSAT module concept):
    - `rw_m1`, `rw_m2`, `math_m1`, `math_m2`
- `difficulty`:
  - currently set to `2` for all imported questions
- `stem`:
  - imported from `question_text`
- `metadata`:
  - includes `external_id`, `test_id`, `section`, `dsat_module`, `question_number`, and PDF `pages`

### answer_key

For `mcq`:

```json
{ "correct": "B" }
```

For `numeric`:

```json
{ "correct": 45.12, "accepted": [45.125, 45.12, 45.13] }
```

- `correct` remains for backwards compatibility.
- `accepted` is used by the `submit_attempt` function to score numeric responses.

## Bank Structure (Fixed)

We create fixed banks per test and module (icons follow the existing seed conventions):

- Reading & Writing banks: `book.closed.fill`
- Math banks: `function`

- `...-rw-m1`
- `...-rw-m2`
- `...-math-m1`
- `...-math-m2`

SAT and PSAT families are separated by slug prefix:

- `sat-pt4-rw-m1`
- `psat10-pt1-rw-m1`
- `psatnmsqt-pt1-rw-m1`
- `psat89-pt1-rw-m1`

Bank ordering is the official question order, using `question_number` as `position`.

## Idempotency (Stable UUIDs)

The importer uses stable UUIDv5 values:

- `questions.id` = uuid5(URL, `satpdf:question:{external_id}`)
- `question_options.id` = uuid5(URL, `satpdf:option:{question_uuid}:{label}`)
- `question_banks.id` = uuid5(URL, `satpdf:bank:{slug}`) (only if the bank does not already exist)

This allows re-importing to update prompts/answers/options without creating duplicates.

## Running The Import

### Local / Manual

```bash
export SUPABASE_URL=...
export SUPABASE_SERVICE_ROLE_KEY=...

python supabase/seed/import_satpdf.py --input-dir /Users/fg/work/justwater/out/all
```

### CI (GitHub Actions) From Release Asset

This repo includes a workflow `Import SAT/PSAT PDF Dataset (From GitHub Release)`.

1. Create a GitHub Release and upload a zip asset (default name: `satpdf-out-all.zip`).
2. Run the workflow with:
   - `release_tag`
   - `asset_name`

Recommended zip contents (either layout is accepted):

- `out/all/*.questions.json` (and optionally `out/all/index.json`)

or

- `*.questions.json` at the zip root

Dry run:

```bash
python supabase/seed/import_satpdf.py --input-dir /Users/fg/work/justwater/out/all --dry-run
```

Single test:

```bash
python supabase/seed/import_satpdf.py --input-dir /Users/fg/work/justwater/out/all --only-test sat-practice-test-4
```
