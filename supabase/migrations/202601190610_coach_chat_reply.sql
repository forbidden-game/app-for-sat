alter table public.coach_thread_messages
  add column if not exists reply_to_message_id uuid references public.coach_thread_messages(id) on delete set null;

create index if not exists coach_thread_messages_reply_to_idx
  on public.coach_thread_messages (reply_to_message_id);
