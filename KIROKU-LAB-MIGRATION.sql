-- KIROKU Lab + Community: character boards, stats, trophies and public sharing.
-- Supabase Dashboard -> SQL Editor -> New query -> run this file once.
-- Safe to re-run. It does NOT recreate profiles, anime_catalog or user_anime.

-- ---------------------------------------------------------------------------
-- 1. Sharing flags on profiles
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists share_anime boolean not null default true;
alter table public.profiles add column if not exists share_tiers boolean not null default true;
alter table public.profiles add column if not exists share_trophies boolean not null default true;

update public.profiles
   set share_anime = true where share_anime is null;
update public.profiles
   set share_tiers = true where share_tiers is null;
update public.profiles
   set share_trophies = true where share_trophies is null;

alter table public.profiles alter column share_anime set not null;
alter table public.profiles alter column share_tiers set not null;
alter table public.profiles alter column share_trophies set not null;

-- Profiles are browsable, but only the safe columns are exposed to members.
alter table public.profiles enable row level security;

drop policy if exists "Members can browse public profiles" on public.profiles;
create policy "Members can browse public profiles"
  on public.profiles for select to authenticated
  using (true);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

revoke select on public.profiles from public, anon, authenticated;
grant select (id, username, display_name, role, premium, share_anime, share_tiers, share_trophies)
  on public.profiles to authenticated;
grant insert (id, username, display_name, role, premium)
  on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Anime lists: own rows + rows whose owner opted in
-- ---------------------------------------------------------------------------
alter table public.user_anime enable row level security;

drop policy if exists "Members can read shared anime lists" on public.user_anime;
create policy "Members can read shared anime lists"
  on public.user_anime for select to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.profiles p
      where p.id = user_anime.user_id
        and coalesce(p.share_anime, true)
    )
  );

grant select on public.user_anime to authenticated;
grant insert, update, delete on public.user_anime to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Lab data: raw rows stay private; the view below publishes masked copies
-- ---------------------------------------------------------------------------
create table if not exists public.user_kiroku_data (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  tiers jsonb not null default '{"active":"","topics":[]}'::jsonb,
  stats jsonb not null default '{}'::jsonb,
  trophies jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_kiroku_data enable row level security;

drop policy if exists "Users can read their own KIROKU Lab data" on public.user_kiroku_data;
create policy "Users can read their own KIROKU Lab data"
  on public.user_kiroku_data for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own KIROKU Lab data" on public.user_kiroku_data;
create policy "Users can create their own KIROKU Lab data"
  on public.user_kiroku_data for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own KIROKU Lab data" on public.user_kiroku_data;
create policy "Users can update their own KIROKU Lab data"
  on public.user_kiroku_data for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own KIROKU Lab data" on public.user_kiroku_data;
create policy "Users can delete their own KIROKU Lab data"
  on public.user_kiroku_data for delete to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.user_kiroku_data to authenticated;
revoke select on public.user_kiroku_data from public, anon;

-- Keep updated_at useful for the community "refreshed" timestamp.
create or replace function public.kiroku_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists kiroku_lab_touch_updated_at on public.user_kiroku_data;
create trigger kiroku_lab_touch_updated_at
  before update on public.user_kiroku_data
  for each row execute function public.kiroku_touch_updated_at();

-- ---------------------------------------------------------------------------
-- 4. Public community view
-- Runs with view-owner rights so base-table RLS stays private, but it nulls out
-- anything the owner did not agree to share. No raw tiers/trophies leak here.
-- ---------------------------------------------------------------------------
drop view if exists public.kiroku_public_lab;

create view public.kiroku_public_lab
with (security_barrier = true, security_invoker = false) as
select
  d.user_id,
  case when coalesce(p.share_tiers, true) then d.tiers else null::jsonb end as tiers,
  case when coalesce(p.share_trophies, true) then d.trophies else '{}'::jsonb end as trophies,
  d.updated_at
from public.user_kiroku_data d
join public.profiles p on p.id = d.user_id
where coalesce(p.share_tiers, true) or coalesce(p.share_trophies, true);

revoke all on public.kiroku_public_lab from public, anon;
grant select on public.kiroku_public_lab to authenticated;

comment on view public.kiroku_public_lab is
  'Public KIROKU boards with tiers/trophies masked by the owner sharing flags.';

-- ---------------------------------------------------------------------------
-- 5. RPC used by the three privacy switches in Premium
-- ---------------------------------------------------------------------------
create or replace function public.kiroku_set_sharing(
  share_anime boolean default true,
  share_tiers boolean default true,
  share_trophies boolean default true
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_anime boolean := coalesce(share_anime, true);
  v_tiers boolean := coalesce(share_tiers, true);
  v_trophies boolean := coalesce(share_trophies, true);
  v_email text;
  v_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.profiles
     set share_anime = v_anime,
         share_tiers = v_tiers,
         share_trophies = v_trophies
   where id = auth.uid();

  if not found then
    select email into v_email from auth.users where id = auth.uid();
    v_name := nullif(split_part(coalesce(v_email, 'member'), '@', 1), '');
    v_name := left(coalesce(v_name, 'member'), 21) || '_' || substr(replace(auth.uid()::text, '-', ''), 1, 6);

    insert into public.profiles (id, username, display_name, role, premium, share_anime, share_tiers, share_trophies)
    values (auth.uid(), v_name, v_name, 'member', true, v_anime, v_tiers, v_trophies)
    on conflict (id) do update
      set share_anime = excluded.share_anime,
          share_tiers = excluded.share_tiers,
          share_trophies = excluded.share_trophies;
  end if;

  return true;
end;
$$;

revoke all on function public.kiroku_set_sharing(boolean, boolean, boolean) from public, anon;
grant execute on function public.kiroku_set_sharing(boolean, boolean, boolean) to authenticated;

comment on function public.kiroku_set_sharing(boolean, boolean, boolean) is
  'Updates the calling user profile sharing flags; always respects auth.uid().';

-- ---------------------------------------------------------------------------
-- 6. Realtime for cross-device sync of the signed-in account
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_kiroku_data'
  ) then
    alter publication supabase_realtime add table public.user_kiroku_data;
  end if;
end
$$;

comment on table public.user_kiroku_data is
  'Private per-user KIROKU Lab data: character tierlists, statistics and achievements.';

-- Make PostgREST pick up the new columns, view, grants and RPC immediately.
notify pgrst, 'reload schema';
