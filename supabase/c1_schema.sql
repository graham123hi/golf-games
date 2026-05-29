-- ============================================================
-- Sandbagger — Phase C1 database setup
-- Paste this whole file into the Supabase SQL Editor and click "Run".
-- Safe to run once on a fresh project. Creates:
--   1. profiles table (one row per user)
--   2. Row Level Security (RLS) so users only edit their own row
--   3. A trigger that auto-creates a profile when someone signs up
-- ============================================================

-- 1. PROFILES TABLE -----------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text unique not null,
  name         text default '',
  email        text,
  photo_url    text,
  chips        int  not null default 1000,
  wins         int  not null default 0,
  rounds       int  not null default 0,
  course       text default '',
  ghin_number  text default '',
  venmo        text default '',
  cashapp      text default '',
  zelle        text default '',
  hc_rounds    jsonb not null default '[]'::jsonb,
  friend_code  text unique not null,
  created_at   timestamptz not null default now()
);

-- 2. ROW LEVEL SECURITY -------------------------------------
alter table public.profiles enable row level security;

-- Any logged-in user can read profiles (needed later to find friends).
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

-- A user can update ONLY their own profile row.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- (No INSERT policy needed: the trigger below inserts the row for us
--  using SECURITY DEFINER, which safely bypasses RLS just for that step.)

-- 3. AUTO-CREATE A PROFILE ON SIGNUP ------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  base_username  text;
  final_username text;
  suffix         int := 0;
  new_code       text;
begin
  -- Build a clean username: from the chosen username, else the email prefix.
  -- Lowercase FIRST, then strip anything that isn't a-z or 0-9 (so capital
  -- letters become lowercase instead of being deleted).
  base_username := regexp_replace(
    lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1))),
    '[^a-z0-9]', '', 'g');
  if base_username is null or base_username = '' then
    base_username := 'golfer';
  end if;

  -- Make the username unique (append 1, 2, 3... if taken).
  final_username := base_username;
  while exists (select 1 from public.profiles where username = final_username) loop
    suffix := suffix + 1;
    final_username := base_username || suffix::text;
  end loop;

  -- Generate a unique GF-XXXXXX friend code.
  loop
    new_code := 'GF-' || upper(substr(md5(random()::text), 1, 6));
    exit when not exists (select 1 from public.profiles where friend_code = new_code);
  end loop;

  insert into public.profiles (id, username, name, email, friend_code)
  values (
    new.id,
    final_username,
    coalesce(new.raw_user_meta_data->>'name', ''),
    new.email,
    new_code
  );
  return new;
end;
$$;

-- Run the function every time a new auth user is created.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
