export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      admin_audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: string
          payload: Json
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: string
          payload?: Json
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: string
          payload?: Json
        }
        Relationships: [
          {
            foreignKeyName: "admin_audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_agent_logs: {
        Row: {
          attempt_id: string | null
          created_at: string | null
          error: string | null
          events: Json
          id: string
          job_id: string | null
          kind: string
          model_id: string
          model_provider: string
          prompt_version: string | null
          prompts: Json
          status: string
          student_id: string | null
          system_prompt: string | null
        }
        Insert: {
          attempt_id?: string | null
          created_at?: string | null
          error?: string | null
          events?: Json
          id?: string
          job_id?: string | null
          kind: string
          model_id: string
          model_provider: string
          prompt_version?: string | null
          prompts?: Json
          status: string
          student_id?: string | null
          system_prompt?: string | null
        }
        Update: {
          attempt_id?: string | null
          created_at?: string | null
          error?: string | null
          events?: Json
          id?: string
          job_id?: string | null
          kind?: string
          model_id?: string
          model_provider?: string
          prompt_version?: string | null
          prompts?: Json
          status?: string
          student_id?: string | null
          system_prompt?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ai_agent_logs_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: false
            referencedRelation: "attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_agent_logs_job_id_fkey"
            columns: ["job_id"]
            isOneToOne: false
            referencedRelation: "ai_jobs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_agent_logs_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_explanations: {
        Row: {
          content: string
          cost_usd: number | null
          created_at: string | null
          model: string
          prompt_version: string
          question_id: string
        }
        Insert: {
          content: string
          cost_usd?: number | null
          created_at?: string | null
          model: string
          prompt_version: string
          question_id: string
        }
        Update: {
          content?: string
          cost_usd?: number | null
          created_at?: string | null
          model?: string
          prompt_version?: string
          question_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ai_explanations_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: true
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_jobs: {
        Row: {
          attempt_count: number
          attempt_id: string | null
          completed_at: string | null
          created_at: string | null
          dedupe_key: string | null
          error: string | null
          id: string
          kind: string
          last_error: string | null
          last_error_at: string | null
          last_error_code: string | null
          locked_at: string | null
          locked_by: string | null
          payload: Json
          run_after: string
          status: string
          student_id: string | null
          updated_at: string | null
        }
        Insert: {
          attempt_count?: number
          attempt_id?: string | null
          completed_at?: string | null
          created_at?: string | null
          dedupe_key?: string | null
          error?: string | null
          id?: string
          kind: string
          last_error?: string | null
          last_error_at?: string | null
          last_error_code?: string | null
          locked_at?: string | null
          locked_by?: string | null
          payload?: Json
          run_after?: string
          status?: string
          student_id?: string | null
          updated_at?: string | null
        }
        Update: {
          attempt_count?: number
          attempt_id?: string | null
          completed_at?: string | null
          created_at?: string | null
          dedupe_key?: string | null
          error?: string | null
          id?: string
          kind?: string
          last_error?: string | null
          last_error_at?: string | null
          last_error_code?: string | null
          locked_at?: string | null
          locked_by?: string | null
          payload?: Json
          run_after?: string
          status?: string
          student_id?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ai_jobs_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: false
            referencedRelation: "attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_jobs_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_prompt_configs: {
        Row: {
          created_at: string | null
          created_by: string | null
          id: string
          kind: string
          model_id: string
          model_provider: string
          notes: string | null
          prompt_version: string
          published_at: string | null
          status: string
          system_prompt: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          id?: string
          kind: string
          model_id: string
          model_provider: string
          notes?: string | null
          prompt_version: string
          published_at?: string | null
          status?: string
          system_prompt: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          id?: string
          kind?: string
          model_id?: string
          model_provider?: string
          notes?: string | null
          prompt_version?: string
          published_at?: string | null
          status?: string
          system_prompt?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      ai_provider_keys: {
        Row: {
          api_key: string
          created_at: string | null
          created_by: string | null
          id: string
          provider: string
          updated_at: string | null
          updated_by: string | null
        }
        Insert: {
          api_key: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          provider: string
          updated_at?: string | null
          updated_by?: string | null
        }
        Update: {
          api_key?: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          provider?: string
          updated_at?: string | null
          updated_by?: string | null
        }
        Relationships: []
      }
      attempt_insights: {
        Row: {
          attempt_id: string
          confidence: number | null
          cost_usd: number | null
          created_at: string | null
          error_mode_detail: string | null
          error_mode_enum: string
          error_step_index: number
          evidence: Json
          explanation_short: string
          followups: Json
          model: string | null
          procedure_id: string
          procedure_steps_version: number
          prompt_version: string | null
          question_id: string
          student_id: string
          student_selected_step_index: number | null
          student_selected_step_is_unknown: boolean
        }
        Insert: {
          attempt_id: string
          confidence?: number | null
          cost_usd?: number | null
          created_at?: string | null
          error_mode_detail?: string | null
          error_mode_enum: string
          error_step_index: number
          evidence?: Json
          explanation_short: string
          followups?: Json
          model?: string | null
          procedure_id: string
          procedure_steps_version: number
          prompt_version?: string | null
          question_id: string
          student_id: string
          student_selected_step_index?: number | null
          student_selected_step_is_unknown?: boolean
        }
        Update: {
          attempt_id?: string
          confidence?: number | null
          cost_usd?: number | null
          created_at?: string | null
          error_mode_detail?: string | null
          error_mode_enum?: string
          error_step_index?: number
          evidence?: Json
          explanation_short?: string
          followups?: Json
          model?: string | null
          procedure_id?: string
          procedure_steps_version?: number
          prompt_version?: string | null
          question_id?: string
          student_id?: string
          student_selected_step_index?: number | null
          student_selected_step_is_unknown?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "attempt_insights_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: true
            referencedRelation: "attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attempt_insights_procedure_id_fkey"
            columns: ["procedure_id"]
            isOneToOne: false
            referencedRelation: "procedures"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attempt_insights_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attempt_insights_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      attempts: {
        Row: {
          answer: Json | null
          client_submission_id: string | null
          created_at: string | null
          duration_ms: number | null
          id: string
          is_correct: boolean | null
          question_id: string | null
          session_id: string | null
          skipped: boolean | null
          student_id: string | null
          student_selected_step_index: number | null
          student_selected_step_is_unknown: boolean
        }
        Insert: {
          answer?: Json | null
          client_submission_id?: string | null
          created_at?: string | null
          duration_ms?: number | null
          id?: string
          is_correct?: boolean | null
          question_id?: string | null
          session_id?: string | null
          skipped?: boolean | null
          student_id?: string | null
          student_selected_step_index?: number | null
          student_selected_step_is_unknown?: boolean
        }
        Update: {
          answer?: Json | null
          client_submission_id?: string | null
          created_at?: string | null
          duration_ms?: number | null
          id?: string
          is_correct?: boolean | null
          question_id?: string | null
          session_id?: string | null
          skipped?: boolean | null
          student_id?: string | null
          student_selected_step_index?: number | null
          student_selected_step_is_unknown?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "attempts_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attempts_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attempts_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_memory_entries: {
        Row: {
          content: string
          created_at: string | null
          id: string
          scope: string
          source: string | null
          student_id: string
          tags: string[] | null
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          scope: string
          source?: string | null
          student_id: string
          tags?: string[] | null
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          scope?: string
          source?: string | null
          student_id?: string
          tags?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "coach_memory_entries_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coach_thread_messages: {
        Row: {
          content: Json
          created_at: string | null
          id: string
          linked_attempt_id: string | null
          reply_to_message_id: string | null
          role: string
          student_id: string
        }
        Insert: {
          content: Json
          created_at?: string | null
          id?: string
          linked_attempt_id?: string | null
          reply_to_message_id?: string | null
          role: string
          student_id: string
        }
        Update: {
          content?: Json
          created_at?: string | null
          id?: string
          linked_attempt_id?: string | null
          reply_to_message_id?: string | null
          role?: string
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "coach_thread_messages_linked_attempt_id_fkey"
            columns: ["linked_attempt_id"]
            isOneToOne: false
            referencedRelation: "attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_thread_messages_reply_to_message_id_fkey"
            columns: ["reply_to_message_id"]
            isOneToOne: false
            referencedRelation: "coach_thread_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "coach_thread_messages_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_events: {
        Row: {
          created_at: string | null
          error: string | null
          event_type: string
          id: string
          locked_at: string | null
          locked_by: string | null
          payload: Json
          status: string
          student_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          error?: string | null
          event_type: string
          id?: string
          locked_at?: string | null
          locked_by?: string | null
          payload?: Json
          status?: string
          student_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          error?: string | null
          event_type?: string
          id?: string
          locked_at?: string | null
          locked_by?: string | null
          payload?: Json
          status?: string
          student_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notification_events_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      parent_invite_codes: {
        Row: {
          code: string
          created_at: string | null
          expires_at: string | null
          id: string
          parent_id: string
          redeemed_at: string | null
          status: string
          student_id: string | null
        }
        Insert: {
          code: string
          created_at?: string | null
          expires_at?: string | null
          id?: string
          parent_id: string
          redeemed_at?: string | null
          status?: string
          student_id?: string | null
        }
        Update: {
          code?: string
          created_at?: string | null
          expires_at?: string | null
          id?: string
          parent_id?: string
          redeemed_at?: string | null
          status?: string
          student_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "parent_invite_codes_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parent_invite_codes_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      parent_student_links: {
        Row: {
          created_at: string | null
          parent_id: string
          status: string
          student_id: string
        }
        Insert: {
          created_at?: string | null
          parent_id: string
          status?: string
          student_id: string
        }
        Update: {
          created_at?: string | null
          parent_id?: string
          status?: string
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "parent_student_links_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parent_student_links_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      procedures: {
        Row: {
          aliases: string[]
          created_at: string | null
          created_by: string
          description: string | null
          id: string
          merged_into: string | null
          name: string
          search_text: string
          status: string
          steps: Json
          steps_version: number
          subject: string
          updated_at: string | null
        }
        Insert: {
          aliases?: string[]
          created_at?: string | null
          created_by?: string
          description?: string | null
          id?: string
          merged_into?: string | null
          name: string
          search_text?: string
          status?: string
          steps?: Json
          steps_version?: number
          subject: string
          updated_at?: string | null
        }
        Update: {
          aliases?: string[]
          created_at?: string | null
          created_by?: string
          description?: string | null
          id?: string
          merged_into?: string | null
          name?: string
          search_text?: string
          status?: string
          steps?: Json
          steps_version?: number
          subject?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "procedures_merged_into_fkey"
            columns: ["merged_into"]
            isOneToOne: false
            referencedRelation: "procedures"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string | null
          display_name: string | null
          id: string
          role: string
        }
        Insert: {
          created_at?: string | null
          display_name?: string | null
          id: string
          role: string
        }
        Update: {
          created_at?: string | null
          display_name?: string | null
          id?: string
          role?: string
        }
        Relationships: []
      }
      push_tokens: {
        Row: {
          created_at: string | null
          device_token: string
          id: string
          last_seen_at: string | null
          platform: string
          student_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          device_token: string
          id?: string
          last_seen_at?: string | null
          platform: string
          student_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          device_token?: string
          id?: string
          last_seen_at?: string | null
          platform?: string
          student_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "push_tokens_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      question_assets: {
        Row: {
          asset_type: string
          asset_url: string
          created_at: string | null
          created_by: string | null
          id: string
          question_id: string | null
          status: string
          storage_path: string | null
        }
        Insert: {
          asset_type: string
          asset_url: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          question_id?: string | null
          status?: string
          storage_path?: string | null
        }
        Update: {
          asset_type?: string
          asset_url?: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          question_id?: string | null
          status?: string
          storage_path?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "question_assets_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
        ]
      }
      question_bank_questions: {
        Row: {
          bank_id: string
          position: number
          question_id: string
        }
        Insert: {
          bank_id: string
          position: number
          question_id: string
        }
        Update: {
          bank_id?: string
          position?: number
          question_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "question_bank_questions_bank_id_fkey"
            columns: ["bank_id"]
            isOneToOne: false
            referencedRelation: "question_banks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "question_bank_questions_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
        ]
      }
      question_banks: {
        Row: {
          created_at: string | null
          icon: string | null
          id: string
          is_active: boolean
          mode: string
          question_limit: number
          rule_json: Json
          slug: string
          sort_order: number
          subtitle: string | null
          title: string
        }
        Insert: {
          created_at?: string | null
          icon?: string | null
          id?: string
          is_active?: boolean
          mode: string
          question_limit?: number
          rule_json?: Json
          slug: string
          sort_order?: number
          subtitle?: string | null
          title: string
        }
        Update: {
          created_at?: string | null
          icon?: string | null
          id?: string
          is_active?: boolean
          mode?: string
          question_limit?: number
          rule_json?: Json
          slug?: string
          sort_order?: number
          subtitle?: string | null
          title?: string
        }
        Relationships: []
      }
      question_options: {
        Row: {
          content: string
          id: string
          label: string
          question_id: string | null
        }
        Insert: {
          content: string
          id?: string
          label: string
          question_id?: string | null
        }
        Update: {
          content?: string
          id?: string
          label?: string
          question_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "question_options_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
        ]
      }
      question_tags: {
        Row: {
          question_id: string
          tag_id: string
        }
        Insert: {
          question_id: string
          tag_id: string
        }
        Update: {
          question_id?: string
          tag_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "question_tags_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "question_tags_tag_id_fkey"
            columns: ["tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
        ]
      }
      question_types: {
        Row: {
          answer_schema: Json
          created_at: string
          display_name: string
          id: string
          is_active: boolean
          name: string
          scoring_type: string
          sort_order: number
        }
        Insert: {
          answer_schema?: Json
          created_at?: string
          display_name: string
          id?: string
          is_active?: boolean
          name: string
          scoring_type?: string
          sort_order?: number
        }
        Update: {
          answer_schema?: Json
          created_at?: string
          display_name?: string
          id?: string
          is_active?: boolean
          name?: string
          scoring_type?: string
          sort_order?: number
        }
        Relationships: []
      }
      questions: {
        Row: {
          answer_key: Json
          created_at: string | null
          difficulty: number
          id: string
          metadata: Json | null
          module: string
          question_type: string
          stem: string
          subject: string
        }
        Insert: {
          answer_key: Json
          created_at?: string | null
          difficulty: number
          id?: string
          metadata?: Json | null
          module: string
          question_type: string
          stem: string
          subject: string
        }
        Update: {
          answer_key?: Json
          created_at?: string | null
          difficulty?: number
          id?: string
          metadata?: Json | null
          module?: string
          question_type?: string
          stem?: string
          subject?: string
        }
        Relationships: [
          {
            foreignKeyName: "questions_type_fk"
            columns: ["question_type"]
            isOneToOne: false
            referencedRelation: "question_types"
            referencedColumns: ["name"]
          },
        ]
      }
      session_questions: {
        Row: {
          assigned_at: string | null
          position: number
          question_id: string
          session_id: string
        }
        Insert: {
          assigned_at?: string | null
          position: number
          question_id: string
          session_id: string
        }
        Update: {
          assigned_at?: string | null
          position?: number
          question_id?: string
          session_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "session_questions_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_questions_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      sessions: {
        Row: {
          bank_id: string | null
          correct_count: number
          created_at: string | null
          id: string
          mode: string
          student_id: string | null
          total_questions: number
        }
        Insert: {
          bank_id?: string | null
          correct_count?: number
          created_at?: string | null
          id?: string
          mode?: string
          student_id?: string | null
          total_questions?: number
        }
        Update: {
          bank_id?: string | null
          correct_count?: number
          created_at?: string | null
          id?: string
          mode?: string
          student_id?: string | null
          total_questions?: number
        }
        Relationships: [
          {
            foreignKeyName: "sessions_bank_id_fkey"
            columns: ["bank_id"]
            isOneToOne: false
            referencedRelation: "question_banks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sessions_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      student_reports: {
        Row: {
          cost_usd: number | null
          created_at: string | null
          delta: Json
          id: string
          metrics: Json
          model: string | null
          period_end: string
          period_key: string
          period_kind: string
          period_start: string
          plan: Json
          prompt_version: string | null
          student_id: string
          summary: string
        }
        Insert: {
          cost_usd?: number | null
          created_at?: string | null
          delta: Json
          id?: string
          metrics: Json
          model?: string | null
          period_end: string
          period_key: string
          period_kind: string
          period_start: string
          plan: Json
          prompt_version?: string | null
          student_id: string
          summary: string
        }
        Update: {
          cost_usd?: number | null
          created_at?: string | null
          delta?: Json
          id?: string
          metrics?: Json
          model?: string | null
          period_end?: string
          period_key?: string
          period_kind?: string
          period_start?: string
          plan?: Json
          prompt_version?: string | null
          student_id?: string
          summary?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_reports_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      student_snapshots: {
        Row: {
          common_error_modes_top: Json
          notes: string | null
          recent_trend: Json
          student_id: string
          subject_scope: string
          updated_at: string | null
          weak_procedures_top: Json
          weak_steps_top: Json
        }
        Insert: {
          common_error_modes_top?: Json
          notes?: string | null
          recent_trend?: Json
          student_id: string
          subject_scope?: string
          updated_at?: string | null
          weak_procedures_top?: Json
          weak_steps_top?: Json
        }
        Update: {
          common_error_modes_top?: Json
          notes?: string | null
          recent_trend?: Json
          student_id?: string
          subject_scope?: string
          updated_at?: string | null
          weak_procedures_top?: Json
          weak_steps_top?: Json
        }
        Relationships: [
          {
            foreignKeyName: "student_snapshots_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      tags: {
        Row: {
          category: string
          id: string
          name: string
        }
        Insert: {
          category: string
          id?: string
          name: string
        }
        Update: {
          category?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
    }
    Views: {
      student_session_stats: {
        Row: {
          accuracy: number | null
          student_id: string | null
          total_correct: number | null
          total_questions: number | null
          total_sessions: number | null
        }
        Relationships: [
          {
            foreignKeyName: "sessions_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      claim_ai_jobs:
        | {
            Args: { p_limit?: number; p_worker_id: string }
            Returns: {
              attempt_count: number
              attempt_id: string | null
              completed_at: string | null
              created_at: string | null
              dedupe_key: string | null
              error: string | null
              id: string
              kind: string
              last_error: string | null
              last_error_at: string | null
              last_error_code: string | null
              locked_at: string | null
              locked_by: string | null
              payload: Json
              run_after: string
              status: string
              student_id: string | null
              updated_at: string | null
            }[]
            SetofOptions: {
              from: "*"
              to: "ai_jobs"
              isOneToOne: false
              isSetofReturn: true
            }
          }
        | {
            Args: { p_kinds?: string[]; p_limit?: number; p_worker_id: string }
            Returns: {
              attempt_count: number
              attempt_id: string | null
              completed_at: string | null
              created_at: string | null
              dedupe_key: string | null
              error: string | null
              id: string
              kind: string
              last_error: string | null
              last_error_at: string | null
              last_error_code: string | null
              locked_at: string | null
              locked_by: string | null
              payload: Json
              run_after: string
              status: string
              student_id: string | null
              updated_at: string | null
            }[]
            SetofOptions: {
              from: "*"
              to: "ai_jobs"
              isOneToOne: false
              isSetofReturn: true
            }
          }
      claim_notification_events: {
        Args: { p_limit?: number; p_worker_id: string }
        Returns: {
          created_at: string | null
          error: string | null
          event_type: string
          id: string
          locked_at: string | null
          locked_by: string | null
          payload: Json
          status: string
          student_id: string
          updated_at: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "notification_events"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      create_parent_invite: {
        Args: { expires_in_hours?: number }
        Returns: string
      }
      get_attempt_for_coach: { Args: { p_attempt_id: string }; Returns: Json }
      get_parent_dashboard: {
        Args: { target_student_id: string; window_days?: number }
        Returns: Json
      }
      get_study_behavior: {
        Args: { target_student_id: string; window_days?: number; history_weeks?: number }
        Returns: Json
      }
      get_session_history: {
        Args: {
          p_bank_id?: string
          p_end?: string
          p_limit?: number
          p_offset?: number
          p_start?: string
        }
        Returns: Json
      }
      get_session_result: { Args: { p_session_id: string }; Returns: Json }
      get_student_period_stats: {
        Args: { p_end: string; p_start: string; p_student_id: string }
        Returns: Json
      }
      import_questions: {
        Args: { p_partial?: boolean; p_payload: Json }
        Returns: Json
      }
      import_questions_to_bank: {
        Args: { p_bank_id?: string; p_partial?: boolean; p_payload: Json }
        Returns: Json
      }
      is_admin: { Args: never; Returns: boolean }
      list_active_students: {
        Args: { p_since: string }
        Returns: {
          student_id: string
        }[]
      }
      redeem_parent_invite: { Args: { invite_code: string }; Returns: string }
      reorder_bank_questions: {
        Args: { p_bank_id: string; p_items: Json }
        Returns: undefined
      }
      search_procedure_candidates: {
        Args: { p_limit?: number; p_query: string; p_subject: string }
        Returns: {
          description: string
          name: string
          procedure_id: string
          similarity: number
          steps: Json
          steps_version: number
        }[]
      }
      show_limit: { Args: never; Returns: number }
      show_trgm: { Args: { "": string }; Returns: string[] }
      start_practice_session: {
        Args: { bank_slug: string; override_limit?: number }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
