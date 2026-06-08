-- Destructive reset for the JuneVersion Swift/iPad app.
-- Run this only after exporting or confirming you do not need old Flutter data.

drop table if exists public.teacher_events cascade;
drop table if exists public.teacher_sessions cascade;
drop table if exists public.teacher_students cascade;

-- Old Flutter-era tables. These names came from the previous app code.
drop table if exists public.problem_history cascade;
drop table if exists public.skills cascade;
drop table if exists public.profiles cascade;

-- If the old app installed auth triggers for profiles, remove the common names.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user() cascade;

-- Recreate the Swift/iPad teacher schema.
create extension if not exists pgcrypto;

create table public.teacher_students (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  math_level text not null check (
    math_level in ('Algebra I', 'Algebra II', 'SAT Math', 'Precalculus')
  ),
  consent_accepted boolean not null default false,
  misconception_counts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teacher_sessions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.teacher_students(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  reflection text not null default '',
  created_at timestamptz not null default now()
);

create table public.teacher_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.teacher_sessions(id) on delete cascade,
  observed_at timestamptz not null default now(),
  mistake_detected boolean not null,
  confidence text not null check (confidence in ('low', 'medium', 'high')),
  misconception_type text not null check (
    misconception_type in (
      'sign_error',
      'distribution',
      'equation_balance',
      'invalid_cancellation',
      'slope_intercept',
      'factoring',
      'sat_strategy',
      'unclear_work'
    )
  ),
  hint_level integer not null check (hint_level between 1 and 4),
  hint text not null,
  teacher_note text not null default '',
  work_summary text not null default '',
  student_self_corrected boolean not null default false,
  final_answer_blocked boolean not null default true
);

create index teacher_sessions_student_id_idx
on public.teacher_sessions(student_id);

create index teacher_events_session_id_idx
on public.teacher_events(session_id);

create index teacher_events_misconception_type_idx
on public.teacher_events(misconception_type);

alter table public.teacher_students enable row level security;
alter table public.teacher_sessions enable row level security;
alter table public.teacher_events enable row level security;

create policy "teacher students authenticated access"
on public.teacher_students
for all
to authenticated
using (true)
with check (true);

create policy "teacher sessions authenticated access"
on public.teacher_sessions
for all
to authenticated
using (true)
with check (true);

create policy "teacher events authenticated access"
on public.teacher_events
for all
to authenticated
using (true)
with check (true);
