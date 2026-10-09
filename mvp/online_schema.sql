create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 32),
  player_code text generated always as ('F17-' || upper(substr(replace(id::text, '-', ''), 1, 12))) stored unique,
  updated_at timestamptz not null default now()
);

create table if not exists public.game_rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  host_id uuid not null references auth.users(id) on delete cascade,
  host_name text not null check (char_length(host_name) between 1 and 32),
  host_address text not null check (char_length(host_address) between 1 and 255),
  port integer not null check (port between 1024 and 65535),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '2 hours')
);

create index if not exists game_rooms_active_code_idx on public.game_rooms (code, expires_at);
create index if not exists game_rooms_host_id_idx on public.game_rooms (host_id);

alter table public.profiles enable row level security;
alter table public.game_rooms enable row level security;

drop policy if exists "authenticated profiles are readable" on public.profiles;
create policy "authenticated profiles are readable" on public.profiles for select to authenticated using (true);
drop policy if exists "users insert own profile" on public.profiles;
create policy "users insert own profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists "authenticated users resolve active rooms" on public.game_rooms;
create policy "authenticated users resolve active rooms" on public.game_rooms for select to authenticated using (expires_at > now());
drop policy if exists "hosts create rooms" on public.game_rooms;
create policy "hosts create rooms" on public.game_rooms for insert to authenticated with check ((select auth.uid()) = host_id);
drop policy if exists "hosts update rooms" on public.game_rooms;
create policy "hosts update rooms" on public.game_rooms for update to authenticated using ((select auth.uid()) = host_id) with check ((select auth.uid()) = host_id);
drop policy if exists "hosts delete rooms" on public.game_rooms;
create policy "hosts delete rooms" on public.game_rooms for delete to authenticated using ((select auth.uid()) = host_id);

grant usage on schema public to authenticated;
grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.game_rooms to authenticated;
revoke all on table public.profiles from anon;
revoke all on table public.game_rooms from anon;

alter table public.game_rooms
  add column if not exists mode text not null default 'ffa' check (mode in ('ffa','tdm')),
  add column if not exists max_players integer not null default 8 check (max_players between 2 and 8),
  add column if not exists kill_limit integer not null default 20 check (kill_limit between 5 and 50),
  add column if not exists match_seconds integer not null default 600 check (match_seconds between 300 and 1800);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create table if not exists public.game_invites (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  room_code text not null references public.game_rooms(code) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '15 minutes'),
  check (sender_id <> recipient_id)
);

create index if not exists friendships_requester_idx on public.friendships(requester_id, status);
create index if not exists friendships_addressee_idx on public.friendships(addressee_id, status);
create index if not exists game_invites_recipient_idx on public.game_invites(recipient_id, status, expires_at);
create index if not exists game_invites_sender_idx on public.game_invites(sender_id, created_at);

alter table public.friendships enable row level security;
alter table public.game_invites enable row level security;

drop policy if exists "participants read friendships" on public.friendships;
create policy "participants read friendships" on public.friendships for select to authenticated using ((select auth.uid()) = requester_id or (select auth.uid()) = addressee_id);
drop policy if exists "users send friend requests" on public.friendships;
create policy "users send friend requests" on public.friendships for insert to authenticated with check ((select auth.uid()) = requester_id and requester_id <> addressee_id and status = 'pending');
drop policy if exists "recipients accept friend requests" on public.friendships;
create policy "recipients accept friend requests" on public.friendships for update to authenticated using ((select auth.uid()) = addressee_id and status = 'pending') with check ((select auth.uid()) = addressee_id and status = 'accepted');
drop policy if exists "participants remove friendships" on public.friendships;
create policy "participants remove friendships" on public.friendships for delete to authenticated using ((select auth.uid()) = requester_id or (select auth.uid()) = addressee_id);

drop policy if exists "participants read game invites" on public.game_invites;
create policy "participants read game invites" on public.game_invites for select to authenticated using ((select auth.uid()) = sender_id or (select auth.uid()) = recipient_id);
drop policy if exists "friends send game invites" on public.game_invites;
create policy "friends send game invites" on public.game_invites for insert to authenticated with check ((select auth.uid()) = sender_id and sender_id <> recipient_id and exists (select 1 from public.friendships f where f.status = 'accepted' and ((f.requester_id = sender_id and f.addressee_id = recipient_id) or (f.requester_id = recipient_id and f.addressee_id = sender_id))));
drop policy if exists "recipients answer game invites" on public.game_invites;
create policy "recipients answer game invites" on public.game_invites for update to authenticated using ((select auth.uid()) = recipient_id and status = 'pending') with check ((select auth.uid()) = recipient_id and status in ('accepted', 'declined'));
drop policy if exists "participants delete game invites" on public.game_invites;
create policy "participants delete game invites" on public.game_invites for delete to authenticated using ((select auth.uid()) = sender_id or (select auth.uid()) = recipient_id);

grant select, insert, update, delete on table public.friendships to authenticated;
grant select, insert, update, delete on table public.game_invites to authenticated;
revoke all on table public.friendships from anon;
revoke all on table public.game_invites from anon;

revoke update on public.friendships, public.game_invites from authenticated;
grant update (status, updated_at) on public.friendships to authenticated;
grant update (status) on public.game_invites to authenticated;
create index if not exists game_invites_room_code_idx on public.game_invites(room_code);

-- Upgrade existing installations as well as new ones.
alter table public.game_rooms drop constraint if exists game_rooms_mode_check;
alter table public.game_rooms add constraint game_rooms_mode_check check (mode in ('ffa','tdm'));
