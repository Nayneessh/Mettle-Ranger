-- Mettle Ranger — log backup schema (spec §5)
--
-- Apply this once to the connected Supabase project (SQL editor, or
-- `supabase db push` if you adopt the CLI). Nothing in this build applies
-- it automatically — there is no real project connected here to apply it
-- against.
--
-- Scope, exactly as spec §5 draws it: text/metadata only. No table here
-- ever holds a file path, a byte count, or anything else describing video
-- on disk — see lib/backup/backup_projection.dart, which enforces the same
-- boundary on the client side before a row ever reaches these tables.
--
-- One-way, last-write-wins: `upsert` from the client always overwrites the
-- matching row here. There is no server-side merge logic because the
-- product design has nothing to merge (single-device use assumed for V1).

create table if not exists public.sessions (
  id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  v integer not null,
  date timestamptz not null,
  discipline text not null,
  gi_flag boolean not null,
  rounds_planned integer not null,
  duration integer not null,
  s_rpe integer,
  partner_count integer not null,
  notes text not null default '',
  mat_time integer not null,
  load_score integer not null,
  synced_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.rounds (
  id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  v integer not null,
  session bigint not null,
  number integer not null,
  duration integer not null,
  mode text not null,
  intensity integer,
  synced_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.chapters (
  id bigint not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  v integer not null,
  session bigint not null,
  round_ref bigint,
  start_offset integer not null,
  end_offset integer not null,
  flagged boolean not null,
  synced_at timestamptz not null default now(),
  primary key (user_id, id)
);

alter table public.sessions enable row level security;
alter table public.rounds enable row level security;
alter table public.chapters enable row level security;

-- A user can only ever read or write their own rows. No cross-user access,
-- no admin bypass defined here — add one deliberately if you ever need it.
create policy "sessions: owner read/write" on public.sessions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "rounds: owner read/write" on public.rounds
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "chapters: owner read/write" on public.chapters
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
