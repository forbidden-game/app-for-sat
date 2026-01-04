insert into public.tags (id, name, category) values
  (gen_random_uuid(), 'Linear equations', 'math'),
  (gen_random_uuid(), 'Main idea', 'reading');

insert into public.questions (subject, module, difficulty, question_type, stem, answer_key)
values
  ('math', 'algebra', 2, 'mcq', 'If x + 2 = 5, what is x?', '{"correct": "B"}');

insert into public.question_options (question_id, label, content)
select q.id, 'A', '1' from public.questions q limit 1;
