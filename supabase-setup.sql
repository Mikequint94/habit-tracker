-- Run this once in your Supabase SQL Editor (https://supabase.com/dashboard -> SQL Editor -> New Query)
create table if not exists public.habit_weeks (
  week_id text primary key,
  start_date text not null,
  payload jsonb not null,
  updated_at timestamptz default now()
);

alter table public.habit_weeks enable row level security;

create policy "Public anon access"
  on public.habit_weeks
  for all
  using (true)
  with check (true);
