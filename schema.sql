-- BunkBoard Team: database setup for Supabase.
-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run.

-- ---------------------------------------------------------------
-- Settings (holds the invite code reps need to sign up)
-- ---------------------------------------------------------------
create table if not exists public.app_settings (
  key   text primary key,
  value text not null
);
insert into public.app_settings (key, value)
values ('invite_code', substr(md5(random()::text || clock_timestamp()::text), 1, 8))
on conflict (key) do nothing;

-- ---------------------------------------------------------------
-- People: one profile per login. The very first signup becomes admin.
-- ---------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  full_name  text not null default '',
  role       text not null default 'rep' check (role in ('admin', 'rep')),
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

create or replace function public.is_active() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and active)
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin' and active)
$$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  first_user boolean;
  code text;
begin
  select not exists (select 1 from public.profiles) into first_user;
  if not first_user then
    select value into code from public.app_settings where key = 'invite_code';
    if coalesce(new.raw_user_meta_data ->> 'invite_code', '') <> coalesce(code, '') then
      raise exception 'Invalid invite code';
    end if;
  end if;
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', ''),
          case when first_user then 'admin' else 'rep' end);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Never leave the company without an active admin.
create or replace function public.guard_last_admin() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.role = 'admin' and old.active
     and (new.role <> 'admin' or not new.active)
     and not exists (select 1 from public.profiles
                     where id <> old.id and role = 'admin' and active) then
    raise exception 'There must be at least one active admin';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_last_admin on public.profiles;
create trigger profiles_guard_last_admin
  before update on public.profiles
  for each row execute function public.guard_last_admin();

-- ---------------------------------------------------------------
-- Clients (the PGs / hostels the team signs up)
-- ---------------------------------------------------------------
create table if not exists public.clients (
  id                 uuid primary key default gen_random_uuid(),
  rep_id             uuid not null references public.profiles (id) default auth.uid(),
  name               text not null check (length(trim(name)) > 0),
  area               text not null default '',
  kind               text not null default 'Women''s PG',
  beds               int  not null default 0 check (beds >= 0),
  owner_name         text not null default '',
  owner_phone        text not null default '',
  phone_key          text generated always as (right(regexp_replace(owner_phone, '\D', '', 'g'), 10)) stored,
  stage              text not null default 'lead' check (stage in ('lead', 'pilot', 'paying', 'lost')),
  stage_changed_at   timestamptz not null default now(),
  lost_reason        text not null default '',
  setup_fee          numeric not null default 0 check (setup_fee >= 0),
  yearly_fee         numeric not null default 0 check (yearly_fee >= 0),
  referred_by_client uuid references public.clients (id) on delete set null,
  referred_by_text   text not null default '',
  assessment         jsonb not null default '{}'::jsonb,
  next_follow_up     date,
  next_follow_up_note text not null default '',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index if not exists clients_rep_idx   on public.clients (rep_id);
create index if not exists clients_phone_idx on public.clients (phone_key);
create index if not exists clients_stage_idx on public.clients (stage);

create or replace function public.clients_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  if new.stage is distinct from old.stage then
    new.stage_changed_at := now();
  end if;
  return new;
end $$;

drop trigger if exists clients_touch_trg on public.clients;
create trigger clients_touch_trg
  before update on public.clients
  for each row execute function public.clients_touch();

-- ---------------------------------------------------------------
-- Visits (log of every visit, call or message)
-- ---------------------------------------------------------------
create table if not exists public.visits (
  id         uuid primary key default gen_random_uuid(),
  client_id  uuid not null references public.clients (id) on delete cascade,
  rep_id     uuid not null references public.profiles (id) default auth.uid(),
  kind       text not null default 'visit' check (kind in ('visit', 'call', 'whatsapp', 'other')),
  note       text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists visits_client_idx on public.visits (client_id);
create index if not exists visits_rep_idx    on public.visits (rep_id, created_at);

-- ---------------------------------------------------------------
-- Duplicate check: tells a rep if another rep already has this phone,
-- without exposing that rep's other clients.
-- ---------------------------------------------------------------
create or replace function public.find_duplicate(p_phone text)
returns table (client_name text, area text, rep_name text, stage text)
language sql stable security definer set search_path = public as $$
  select c.name, c.area, p.full_name, c.stage
  from public.clients c
  join public.profiles p on p.id = c.rep_id
  where public.is_active()
    and length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')) >= 10
    and c.phone_key = right(regexp_replace(p_phone, '\D', '', 'g'), 10)
  limit 3
$$;

-- ---------------------------------------------------------------
-- Row level security: reps see only their own clients; admins see all.
-- ---------------------------------------------------------------
alter table public.app_settings enable row level security;
alter table public.profiles     enable row level security;
alter table public.clients      enable row level security;
alter table public.visits       enable row level security;

drop policy if exists settings_select on public.app_settings;
drop policy if exists settings_update on public.app_settings;
create policy settings_select on public.app_settings for select using (public.is_admin());
create policy settings_update on public.app_settings for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_update on public.profiles;
create policy profiles_select on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy profiles_update on public.profiles for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists clients_select on public.clients;
drop policy if exists clients_insert on public.clients;
drop policy if exists clients_update on public.clients;
drop policy if exists clients_delete on public.clients;
create policy clients_select on public.clients for select
  using (public.is_active() and (rep_id = auth.uid() or public.is_admin()));
create policy clients_insert on public.clients for insert
  with check (public.is_active() and (rep_id = auth.uid() or public.is_admin()));
create policy clients_update on public.clients for update
  using (public.is_active() and (rep_id = auth.uid() or public.is_admin()))
  with check (public.is_active() and (rep_id = auth.uid() or public.is_admin()));
create policy clients_delete on public.clients for delete using (public.is_admin());

drop policy if exists visits_select on public.visits;
drop policy if exists visits_insert on public.visits;
drop policy if exists visits_delete on public.visits;
create policy visits_select on public.visits for select
  using (public.is_active() and exists (
    select 1 from public.clients c
    where c.id = client_id and (c.rep_id = auth.uid() or public.is_admin())));
create policy visits_insert on public.visits for insert
  with check (public.is_active() and rep_id = auth.uid() and exists (
    select 1 from public.clients c
    where c.id = client_id and (c.rep_id = auth.uid() or public.is_admin())));
create policy visits_delete on public.visits for delete
  using (public.is_admin() or (public.is_active() and rep_id = auth.uid()));

-- ---------------------------------------------------------------
-- Permissions: signed-in users only; the public (anon) key sees nothing.
-- ---------------------------------------------------------------
revoke all on public.app_settings, public.profiles, public.clients, public.visits from anon;
grant select, update on public.app_settings to authenticated;
grant select, update on public.profiles     to authenticated;
grant select, insert, update, delete on public.clients to authenticated;
grant select, insert, delete          on public.visits  to authenticated;
revoke all on function public.find_duplicate(text) from public, anon;
grant execute on function public.find_duplicate(text) to authenticated;
