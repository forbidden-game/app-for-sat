#!/usr/bin/env python3
import json
import uuid
from pathlib import Path
from typing import Dict, List, Optional, Tuple


def stable_uuid(name: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, name))


def sql_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_literal(value) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (dict, list)):
        return sql_quote(json.dumps(value, separators=(",", ":")))
    return sql_quote(str(value))


def format_insert(
    table: str,
    columns: List[str],
    rows: List[Dict[str, object]],
    conflict_target: Optional[str] = None,
) -> str:
    if not rows:
        return ""
    lines = [f"insert into {table} ({', '.join(columns)}) values"]
    for i, row in enumerate(rows):
        values = [sql_literal(row[col]) for col in columns]
        suffix = "," if i < len(rows) - 1 else ""
        lines.append("  (" + ", ".join(values) + ")" + suffix)
    if conflict_target:
        lines.append(f"on conflict ({conflict_target}) do nothing;")
    else:
        lines[-1] = lines[-1] + ";"
    return "\n".join(lines)


def build_questions():
    questions = []

    def add_question(
        subject: str,
        module: str,
        difficulty: int,
        question_type: str,
        stem: str,
        answer_key,
        options: Optional[List[Tuple[str, str]]],
        tags: List[str],
    ):
        questions.append(
            {
                "subject": subject,
                "module": module,
                "difficulty": difficulty,
                "question_type": question_type,
                "stem": stem,
                "answer_key": answer_key,
                "options": options or [],
                "tags": tags,
            }
        )

    # Math MCQ
    add_question(
        "math",
        "algebra",
        1,
        "mcq",
        "If x + 5 = 12, what is x?",
        {"correct": "B"},
        [("A", "5"), ("B", "7"), ("C", "12"), ("D", "17")],
        ["Linear equations"],
    )
    add_question(
        "math",
        "algebra",
        1,
        "mcq",
        "If 3x = 18, what is x?",
        {"correct": "B"},
        [("A", "5"), ("B", "6"), ("C", "9"), ("D", "12")],
        ["Linear equations"],
    )
    add_question(
        "math",
        "algebra",
        2,
        "mcq",
        "The system x + y = 10 and x - y = 4. What is x?",
        {"correct": "C"},
        [("A", "3"), ("B", "4"), ("C", "7"), ("D", "6")],
        ["Systems of equations"],
    )
    add_question(
        "math",
        "geometry",
        1,
        "mcq",
        "A rectangle has length 8 and width 3. What is the area?",
        {"correct": "C"},
        [("A", "11"), ("B", "16"), ("C", "24"), ("D", "48")],
        ["Geometry"],
    )
    add_question(
        "math",
        "geometry",
        1,
        "mcq",
        "A triangle has base 10 and height 6. What is the area?",
        {"correct": "B"},
        [("A", "16"), ("B", "30"), ("C", "60"), ("D", "120")],
        ["Geometry"],
    )
    add_question(
        "math",
        "ratios",
        2,
        "mcq",
        "A ratio of boys to girls is 3 to 5. If there are 24 students, how many are girls?",
        {"correct": "C"},
        [("A", "9"), ("B", "12"), ("C", "15"), ("D", "18")],
        ["Ratios and proportions"],
    )
    add_question(
        "math",
        "percent",
        2,
        "mcq",
        "A price of 50 is increased by 20 percent. What is the new price?",
        {"correct": "B"},
        [("A", "55"), ("B", "60"), ("C", "65"), ("D", "70")],
        ["Percent"],
    )
    add_question(
        "math",
        "functions",
        2,
        "mcq",
        "If f(x) = 2x + 1, what is f(4)?",
        {"correct": "C"},
        [("A", "6"), ("B", "8"), ("C", "9"), ("D", "10")],
        ["Functions"],
    )
    add_question(
        "math",
        "data",
        2,
        "mcq",
        "What is the mean of 4, 6, and 10?",
        {"correct": "C"},
        [("A", "6"), ("B", "6.5"), ("C", "20/3"), ("D", "7")],
        ["Data analysis"],
    )
    add_question(
        "math",
        "inequalities",
        2,
        "mcq",
        "Solve x - 3 > 2. Which value satisfies the inequality?",
        {"correct": "C"},
        [("A", "4"), ("B", "5"), ("C", "6"), ("D", "2")],
        ["Inequalities"],
    )

    # Math numeric
    add_question(
        "math",
        "arithmetic",
        1,
        "numeric",
        "Compute 7 * 6.",
        {"correct": 42},
        None,
        ["Data analysis"],
    )
    add_question(
        "math",
        "arithmetic",
        1,
        "numeric",
        "Compute 15 - 9.",
        {"correct": 6},
        None,
        ["Data analysis"],
    )
    add_question(
        "math",
        "arithmetic",
        1,
        "numeric",
        "Compute 12 / 3.",
        {"correct": 4},
        None,
        ["Data analysis"],
    )
    add_question(
        "math",
        "algebra",
        1,
        "numeric",
        "If x + 7 = 20, what is x?",
        {"correct": 13},
        None,
        ["Linear equations"],
    )
    add_question(
        "math",
        "algebra",
        1,
        "numeric",
        "If 4x = 28, what is x?",
        {"correct": 7},
        None,
        ["Linear equations"],
    )
    add_question(
        "math",
        "arithmetic",
        2,
        "numeric",
        "Compute 9 squared.",
        {"correct": 81},
        None,
        ["Data analysis"],
    )
    add_question(
        "math",
        "geometry",
        2,
        "numeric",
        "A rectangle has length 5 and width 7. What is the perimeter?",
        {"correct": 24},
        None,
        ["Geometry"],
    )
    add_question(
        "math",
        "data",
        2,
        "numeric",
        "What is the mean of 2, 4, 6, and 8?",
        {"correct": 5},
        None,
        ["Data analysis"],
    )
    add_question(
        "math",
        "percent",
        2,
        "numeric",
        "What is 25 percent of 80?",
        {"correct": 20},
        None,
        ["Percent"],
    )
    add_question(
        "math",
        "functions",
        2,
        "numeric",
        "If y = 3x and x = 5, what is y?",
        {"correct": 15},
        None,
        ["Functions"],
    )

    # Reading MCQ
    add_question(
        "reading",
        "comprehension",
        1,
        "mcq",
        "Solar panels convert sunlight into electricity and reduce reliance on fossil fuels. Which choice best states the main idea of the sentence?",
        {"correct": "A"},
        [
            ("A", "Solar panels provide clean energy from sunlight."),
            ("B", "Fossil fuels are abundant."),
            ("C", "Electricity is difficult to store."),
            ("D", "Sunlight is harmful."),
        ],
        ["Main idea"],
    )
    add_question(
        "reading",
        "comprehension",
        1,
        "mcq",
        "The library was quiet, and the students whispered. What can be inferred about the setting?",
        {"correct": "B"},
        [
            ("A", "It is a noisy stadium."),
            ("B", "People are reading or studying."),
            ("C", "A concert is starting."),
            ("D", "A storm is approaching."),
        ],
        ["Inference"],
    )
    add_question(
        "reading",
        "vocabulary",
        1,
        "mcq",
        "The scientist was meticulous in recording each measurement. What is the closest meaning of meticulous?",
        {"correct": "B"},
        [
            ("A", "Careless"),
            ("B", "Precise"),
            ("C", "Angry"),
            ("D", "Hurried"),
        ],
        ["Vocabulary"],
    )
    add_question(
        "reading",
        "grammar",
        1,
        "mcq",
        "Each of the players have a locker. Which change corrects the error?",
        {"correct": "B"},
        [("A", "have"), ("B", "has"), ("C", "having"), ("D", "to have")],
        ["Grammar"],
    )
    add_question(
        "reading",
        "evidence",
        2,
        "mcq",
        "The report states that exercise improves sleep, and the survey shows longer sleep among active adults. Which detail best supports the claim?",
        {"correct": "A"},
        [
            ("A", "The survey shows longer sleep among active adults."),
            ("B", "Some adults own gym shoes."),
            ("C", "Sleep requires a bed."),
            ("D", "Exercise can be fun."),
        ],
        ["Evidence"],
    )
    add_question(
        "reading",
        "tone",
        1,
        "mcq",
        "The author celebrates the invention as a breakthrough. Which word best describes the tone?",
        {"correct": "B"},
        [("A", "Critical"), ("B", "Enthusiastic"), ("C", "Indifferent"), ("D", "Fearful")],
        ["Tone"],
    )
    add_question(
        "reading",
        "purpose",
        1,
        "mcq",
        "The passage explains how to apply for a passport. What is the primary purpose of the passage?",
        {"correct": "A"},
        [("A", "To instruct"), ("B", "To entertain"), ("C", "To argue"), ("D", "To narrate")],
        ["Purpose"],
    )
    add_question(
        "reading",
        "structure",
        2,
        "mcq",
        "The paragraph lists causes of pollution and then describes effects. Which structure does this use?",
        {"correct": "A"},
        [
            ("A", "Cause and effect"),
            ("B", "Chronological"),
            ("C", "Compare and contrast"),
            ("D", "Problem and solution"),
        ],
        ["Structure"],
    )
    add_question(
        "reading",
        "vocabulary",
        1,
        "mcq",
        "The audience was captivated by the performance. What does captivated mean?",
        {"correct": "B"},
        [("A", "Bored"), ("B", "Held attention"), ("C", "Confused"), ("D", "Sleepy")],
        ["Vocabulary"],
    )
    add_question(
        "reading",
        "comprehension",
        1,
        "mcq",
        "After the rain stopped, the streets glistened. What can be inferred?",
        {"correct": "B"},
        [("A", "It is nighttime."), ("B", "The streets are wet."), ("C", "The streets are closed."), ("D", "It is snowing.")],
        ["Inference"],
    )
    add_question(
        "reading",
        "comprehension",
        1,
        "mcq",
        "The new policy reduces waste by encouraging recycling and reuse. Which choice best states the main idea?",
        {"correct": "A"},
        [
            ("A", "The policy reduces waste through recycling and reuse."),
            ("B", "Recycling is unpopular."),
            ("C", "Waste is unavoidable."),
            ("D", "Policies are difficult to change."),
        ],
        ["Main idea"],
    )
    add_question(
        "reading",
        "grammar",
        1,
        "mcq",
        "Neither of the answers are correct. Which change corrects the error?",
        {"correct": "B"},
        [("A", "are"), ("B", "is"), ("C", "be"), ("D", "been")],
        ["Grammar"],
    )
    add_question(
        "reading",
        "evidence",
        2,
        "mcq",
        "The study notes that cities with more trees have lower temperatures. Which detail best supports the claim?",
        {"correct": "A"},
        [
            ("A", "Cities with more trees have lower temperatures."),
            ("B", "Some cities plant flowers."),
            ("C", "Trees can be tall."),
            ("D", "Temperatures change by season."),
        ],
        ["Evidence"],
    )
    add_question(
        "reading",
        "tone",
        2,
        "mcq",
        "The review calls the product disappointing and flawed. Which word best describes the tone?",
        {"correct": "A"},
        [("A", "Critical"), ("B", "Joyful"), ("C", "Neutral"), ("D", "Hopeful")],
        ["Tone"],
    )
    add_question(
        "reading",
        "purpose",
        1,
        "mcq",
        "The flyer invites residents to a community meeting on Tuesday. What is the primary purpose of the flyer?",
        {"correct": "A"},
        [("A", "To invite"), ("B", "To warn"), ("C", "To complain"), ("D", "To instruct")],
        ["Purpose"],
    )
    add_question(
        "reading",
        "structure",
        2,
        "mcq",
        "The passage compares electric cars and gas cars. Which structure does this use?",
        {"correct": "C"},
        [
            ("A", "Cause and effect"),
            ("B", "Chronological"),
            ("C", "Compare and contrast"),
            ("D", "Problem and solution"),
        ],
        ["Structure"],
    )
    add_question(
        "reading",
        "vocabulary",
        1,
        "mcq",
        "The plan was feasible given the budget. What does feasible mean?",
        {"correct": "B"},
        [("A", "Risky"), ("B", "Possible"), ("C", "Hidden"), ("D", "Temporary")],
        ["Vocabulary"],
    )
    add_question(
        "reading",
        "comprehension",
        1,
        "mcq",
        "She packed an umbrella and checked the forecast. What can be inferred?",
        {"correct": "A"},
        [("A", "She expects rain."), ("B", "She dislikes weather."), ("C", "She is late."), ("D", "She is traveling by train.")],
        ["Inference"],
    )
    add_question(
        "reading",
        "comprehension",
        1,
        "mcq",
        "Regular practice improves performance in music. Which choice best states the main idea?",
        {"correct": "A"},
        [
            ("A", "Practice improves music performance."),
            ("B", "Music is hard to learn."),
            ("C", "Performance is about talent."),
            ("D", "Regular schedules are boring."),
        ],
        ["Main idea"],
    )
    add_question(
        "reading",
        "grammar",
        2,
        "mcq",
        "The committee has reached their decision. Which change corrects the error?",
        {"correct": "B"},
        [("A", "their"), ("B", "its"), ("C", "they"), ("D", "them")],
        ["Grammar"],
    )

    return questions


def build_seed() -> Dict[str, List[Dict[str, object]]]:
    tags = [
        {"name": "Linear equations", "category": "math"},
        {"name": "Systems of equations", "category": "math"},
        {"name": "Geometry", "category": "math"},
        {"name": "Ratios and proportions", "category": "math"},
        {"name": "Percent", "category": "math"},
        {"name": "Functions", "category": "math"},
        {"name": "Data analysis", "category": "math"},
        {"name": "Inequalities", "category": "math"},
        {"name": "Main idea", "category": "reading"},
        {"name": "Inference", "category": "reading"},
        {"name": "Vocabulary", "category": "reading"},
        {"name": "Evidence", "category": "reading"},
        {"name": "Grammar", "category": "reading"},
        {"name": "Tone", "category": "reading"},
        {"name": "Structure", "category": "reading"},
        {"name": "Purpose", "category": "reading"},
    ]

    tag_rows: List[Dict[str, object]] = []
    tag_ids: Dict[str, str] = {}
    for tag in tags:
        tag_id = stable_uuid(f"tag:{tag['category']}:{tag['name']}")
        tag_ids[tag["name"]] = tag_id
        tag_rows.append({"id": tag_id, "name": tag["name"], "category": tag["category"]})

    questions = build_questions()

    question_rows: List[Dict[str, object]] = []
    option_rows: List[Dict[str, object]] = []
    question_tag_rows: List[Dict[str, object]] = []

    for q in questions:
        q_id = stable_uuid(f"question:{q['stem']}")
        question_rows.append(
            {
                "id": q_id,
                "subject": q["subject"],
                "module": q["module"],
                "difficulty": q["difficulty"],
                "question_type": q["question_type"],
                "stem": q["stem"],
                "answer_key": q["answer_key"],
            }
        )

        for label, content in q["options"]:
            opt_id = stable_uuid(f"option:{q_id}:{label}")
            option_rows.append(
                {
                    "id": opt_id,
                    "question_id": q_id,
                    "label": label,
                    "content": content,
                }
            )

        for tag_name in q["tags"]:
            tag_id = tag_ids.get(tag_name)
            if tag_id is None:
                raise ValueError(f"Unknown tag: {tag_name}")
            question_tag_rows.append({"question_id": q_id, "tag_id": tag_id})

    if len(questions) < 30:
        raise ValueError("Expected at least 30 questions for minimal validation")

    return {
        "tags": tag_rows,
        "questions": question_rows,
        "question_options": option_rows,
        "question_tags": question_tag_rows,
    }


def main() -> int:
    seed = build_seed()

    sections = [
        "-- Generated by supabase/seed/generate_seed.py. Do not edit by hand.",
        "",
        format_insert("public.tags", ["id", "name", "category"], seed["tags"], conflict_target="id"),
        "",
        format_insert(
            "public.questions",
            ["id", "subject", "module", "difficulty", "question_type", "stem", "answer_key"],
            seed["questions"],
            conflict_target="id",
        ),
        "",
        format_insert(
            "public.question_options",
            ["id", "question_id", "label", "content"],
            seed["question_options"],
            conflict_target="id",
        ),
        "",
        format_insert(
            "public.question_tags",
            ["question_id", "tag_id"],
            seed["question_tags"],
            conflict_target="question_id,tag_id",
        ),
        "",
    ]

    output = "\n".join(section for section in sections if section)

    seed_path = Path(__file__).resolve().parents[1] / "seed.sql"
    seed_path.write_text(output + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
