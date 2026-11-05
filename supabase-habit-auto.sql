-- Automatic habits: run once in the Supabase SQL Editor (the project shared by habit-tracker,
-- veg-macro-calc and morning-briefing).
--
-- Every morning, morning-briefing writes one row per day to habit_auto:
--   * last night's sleep (bedtime, wake time, minutes asleep) from the Google Health API
--   * that day's protein and first meal time from veg-macro-calc's food log
-- The habit tracker reads habit_auto and fills in "Sleep before 12:30am", "150g+ protein",
-- "Breakfast before 11am" and the weekly sleep / bedtime averages.
--
-- Security: morning-briefing has NO admin (service role) key. It can only call the two functions
-- below, and only with HABIT_SYNC_SECRET. One returns just the food-log days asked for; the other
-- writes habit_auto rows. Nothing else in the project is reachable with the secret.

-- 1. Daily automatic values ---------------------------------------------------------------
create table if not exists public.habit_auto (
  day                date primary key,      -- the habit day (sleep = the night that started on this day)
  bedtime            timestamptz,
  wake_time          timestamptz,
  asleep_minutes     integer,
  protein_g          integer,
  food_items         integer,                -- 0 = nothing logged that day (protein is then unknown)
  first_meal_at      timestamptz,            -- earliest food logged on this day
  updated_at         timestamptz not null default now()
);

alter table public.habit_auto enable row level security;

-- The habit tracker reads with the public key (the same access habit_weeks has).
drop policy if exists "Public read" on public.habit_auto;
create policy "Public read" on public.habit_auto for select using (true);
-- No insert/update/delete policies: only habit_sync_write (below) can change rows.
revoke insert, update, delete on public.habit_auto from anon, authenticated;

-- 2. Sync secret (stored hashed, unreadable through the API) ----------------------------------
create table if not exists public.habit_sync_config (
  id          integer primary key default 1 check (id = 1),
  user_id     uuid not null references auth.users (id) on delete cascade,  -- whose food log to read
  secret_hash text not null                                                 -- sha256 of HABIT_SYNC_SECRET
);

alter table public.habit_sync_config enable row level security;  -- no policies = no API access
revoke all on public.habit_sync_config from anon, authenticated;

-- Returns the configured user's id if the secret matches, otherwise raises.
create or replace function public.habit_sync_user(p_secret text)
returns uuid
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  uid uuid;
begin
  select user_id into uid
  from habit_sync_config
  where secret_hash = encode(digest(coalesce(p_secret, ''), 'sha256'), 'hex');
  if uid is null then
    raise exception 'invalid habit sync secret' using errcode = '28000';
  end if;
  return uid;
end;
$$;
revoke all on function public.habit_sync_user(text) from public, anon, authenticated;

-- 3. Read: only the requested days of the veg-macro-calc food log (max 14 days) ---------------
create or replace function public.habit_sync_food_logs(p_secret text, p_days date[])
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  uid uuid := habit_sync_user(p_secret);
  result jsonb;
begin
  if coalesce(array_length(p_days, 1), 0) > 14 then
    raise exception 'ask for at most 14 days';
  end if;
  select coalesce(jsonb_object_agg(d::text, s.state -> 'logsByDate' -> (d::text)), '{}'::jsonb)
    into result
  from user_state s
  cross join unnest(p_days) as d
  where s.user_id = uid
    and s.state -> 'logsByDate' ? (d::text);
  return result;
end;
$$;
revoke all on function public.habit_sync_food_logs(text, date[]) from public, authenticated;
grant execute on function public.habit_sync_food_logs(text, date[]) to anon;

-- 4. Write: upsert habit_auto rows. A null field keeps the existing value, so a failed
--    sleep fetch never erases sleep that was already recorded.
create or replace function public.habit_sync_write(p_secret text, p_rows jsonb)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  n integer;
begin
  perform habit_sync_user(p_secret);
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 31 then
    raise exception 'p_rows must be an array of at most 31 days';
  end if;

  insert into habit_auto (day, bedtime, wake_time, asleep_minutes, protein_g, food_items, first_meal_at, updated_at)
  select (r ->> 'day')::date,
         (r ->> 'bedtime')::timestamptz,
         (r ->> 'wake_time')::timestamptz,
         (r ->> 'asleep_minutes')::integer,
         (r ->> 'protein_g')::integer,
         (r ->> 'food_items')::integer,
         (r ->> 'first_meal_at')::timestamptz,
         now()
  from jsonb_array_elements(p_rows) as r
  on conflict (day) do update set
    bedtime        = coalesce(excluded.bedtime,        habit_auto.bedtime),
    wake_time      = coalesce(excluded.wake_time,      habit_auto.wake_time),
    asleep_minutes = coalesce(excluded.asleep_minutes, habit_auto.asleep_minutes),
    protein_g      = coalesce(excluded.protein_g,      habit_auto.protein_g),
    food_items     = coalesce(excluded.food_items,     habit_auto.food_items),
    first_meal_at  = coalesce(excluded.first_meal_at,  habit_auto.first_meal_at),
    updated_at     = now();

  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.habit_sync_write(text, jsonb) from public, authenticated;
grant execute on function public.habit_sync_write(text, jsonb) to anon;

-- 5. ONE-TIME: set the secret and pick your account --------------------------------------------
-- Generate a secret on your computer:   openssl rand -hex 32
-- Put the same value in morning-briefing's .env and GitHub secrets as HABIT_SYNC_SECRET.
-- Use the email you sign in to veg-macro-calc with. Then run just this statement:
--
-- insert into public.habit_sync_config (id, user_id, secret_hash)
-- select 1, id, encode(extensions.digest('PASTE_SECRET_HERE', 'sha256'), 'hex')
-- from auth.users
-- where email = 'YOUR_VEG_MACRO_CALC_EMAIL'
-- on conflict (id) do update set user_id = excluded.user_id, secret_hash = excluded.secret_hash;
