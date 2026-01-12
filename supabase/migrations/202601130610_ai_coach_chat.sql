-- AI Coach: enable chat jobs and realtime streaming

-- 1) Expand ai_jobs.kind constraint to allow coach_reply
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ai_jobs_kind_check'
      AND conrelid = 'public.ai_jobs'::regclass
  ) THEN
    ALTER TABLE public.ai_jobs DROP CONSTRAINT ai_jobs_kind_check;
  END IF;

  ALTER TABLE public.ai_jobs
    ADD CONSTRAINT ai_jobs_kind_check
    CHECK (kind IN ('attempt_insight','thread_summary','procedure_merge','coach_reply'));
EXCEPTION
  WHEN undefined_table THEN
    -- Running before ai_jobs exists (shouldn't happen), ignore.
    NULL;
END $$;

-- 2) Ensure coach_thread_messages is in realtime publication (for insert/update streaming)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.coach_thread_messages;
    EXCEPTION
      WHEN duplicate_object THEN
        NULL;
    END;
  END IF;
END $$;

-- 3) (Optional) Also enable realtime for attempt_insights (useful for future UI)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.attempt_insights;
    EXCEPTION
      WHEN duplicate_object THEN
        NULL;
    END;
  END IF;
END $$;
