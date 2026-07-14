-- 在 Supabase SQL Editor 里整段执行（免费版即可）

create extension if not exists "pgcrypto";

-- 用户档案
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  couple_id uuid,
  fcm_token text,
  created_at timestamptz default now()
);

-- 情侣空间（两人绑定）
create table if not exists couples (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  member_a uuid,
  member_b uuid,
  created_at timestamptz default now()
);

-- 实时位置
create table if not exists live_locations (
  user_id uuid primary key references auth.users(id) on delete cascade,
  couple_id uuid,
  lat double precision,
  lng double precision,
  accuracy double precision,
  sharing boolean default true,
  updated_at timestamptz default now()
);

-- 共享回忆
create table if not exists memories (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid,
  author_id uuid references auth.users(id) on delete cascade,
  type text,
  content text,
  media_path text,
  lat double precision,
  lng double precision,
  created_at timestamptz default now()
);

-- 返回当前用户所在的情侣空间 id
create or replace function my_couple_id() returns uuid
language sql stable as $$
  select couple_id from profiles where id = auth.uid()
$$;

-- 行级安全：只有绑定双方能读彼此数据
alter table profiles enable row level security;
alter table couples enable row level security;
alter table live_locations enable row level security;
alter table memories enable row level security;

create policy "profiles_visible" on profiles for select using (couple_id = my_couple_id());
create policy "profiles_update_self" on profiles for update using (id = auth.uid());
create policy "profiles_insert_self" on profiles for insert with check (id = auth.uid());

create policy "couples_visible" on couples for select using (member_a = auth.uid() or member_b = auth.uid());

create policy "loc_read" on live_locations for select using (couple_id = my_couple_id());
create policy "loc_write" on live_locations for insert with check (user_id = auth.uid());
create policy "loc_update" on live_locations for update using (user_id = auth.uid());

-- 历史轨迹（爱情足迹地图用）：追加写入，仅两人可读
create table if not exists location_history (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete cascade,
  couple_id uuid,
  lat double precision not null,
  lng double precision not null,
  accuracy double precision,
  created_at timestamptz default now()
);

alter table location_history enable row level security;
create policy "lh_read" on location_history for select using (couple_id = my_couple_id());
create policy "lh_write" on location_history for insert with check (user_id = auth.uid() and couple_id = my_couple_id());
create index if not exists location_history_couple_time_idx on location_history (couple_id, created_at);

-- 定时清理（个人两人用，可按需执行，保留最近 60 天避免无限增长）：
-- delete from location_history where created_at < now() - interval '60 days';

create policy "mem_read" on memories for select using (couple_id = my_couple_id());
create policy "mem_insert" on memories for insert with check (author_id = auth.uid() and couple_id = my_couple_id());
create policy "mem_delete" on memories for delete using (couple_id = my_couple_id());

-- 新用户自动建档案
create or replace function handle_new_user() returns trigger
language plpgsql as $$
begin
  insert into profiles (id) values (new.id) on conflict do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user();

-- 存储：在 Supabase 控制台新建一个名为 memories 的 public bucket 后，
-- 允许已登录用户上传（读取对 public bucket 默认开放）
create policy "memories_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'memories');

-- ============ 自动报备（地理围栏）============

-- 地理围栏（自动报备地点），每人可设多个
create table if not exists geofences (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete cascade,
  couple_id uuid,
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  radius_m double precision not null default 150,
  created_at timestamptz default now()
);

-- 自动报备事件（进出围栏时写入，伴侣端实时收到）
create table if not exists checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  couple_id uuid,
  geofence_id uuid,
  event_type text not null check (event_type in ('enter', 'exit')),
  place_name text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz default now()
);

alter table geofences enable row level security;
alter table checkins enable row level security;

create policy "geo_read" on geofences for select using (couple_id = my_couple_id());
create policy "geo_write" on geofences for insert with check (owner_id = auth.uid() and couple_id = my_couple_id());
create policy "geo_delete" on geofences for delete using (owner_id = auth.uid());

create policy "check_read" on checkins for select using (couple_id = my_couple_id());
create policy "check_write" on checkins for insert with check (user_id = auth.uid() and couple_id = my_couple_id());

-- 让报备事件可被 Realtime 监听（伴侣端实时弹通知）
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'checkins') then
    alter publication supabase_realtime add table checkins;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'live_locations') then
    alter publication supabase_realtime add table live_locations;
  end if;
end $$;

-- ============ 纪念日 / 在一起天数 ============
alter table couples add column if not exists together_since date;

create table if not exists milestones (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid,
  title text not null,
  m_date date not null,
  emoji text default '💖',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

-- ============ 每日一问 ============
create table if not exists daily_answers (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid,
  q_date date not null,
  question text not null,
  user_id uuid references auth.users(id) on delete cascade,
  answer text not null,
  created_at timestamptz default now(),
  unique (couple_id, q_date, user_id)
);

-- ============ 100件小事（共享完成集合）============
create table if not exists couple_meta (
  couple_id uuid primary key references couples(id) on delete cascade,
  done_bucket int[] default '{}',
  updated_at timestamptz default now()
);

-- ============ 心情日记 + 早晚安 ============
create table if not exists moods (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid,
  user_id uuid references auth.users(id) on delete cascade,
  m_date date not null,
  mood text not null,
  note text,
  created_at timestamptz default now(),
  unique (couple_id, user_id, m_date)
);

create table if not exists greetings (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid,
  user_id uuid references auth.users(id) on delete cascade,
  g_date date not null,
  kind text not null check (kind in ('morning','evening')),
  created_at timestamptz default now(),
  unique (couple_id, user_id, g_date, kind)
);

-- ============ 共同歌单 / 一起看片 ============
create table if not exists songlist (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid,
  title text not null,
  artist text,
  added_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

create table if not exists watchlist (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid,
  title text not null,
  note text,
  added_by uuid references auth.users(id) on delete set null,
  watched boolean default false,
  created_at timestamptz default now()
);

-- ============ 默契小游戏 ============
create table if not exists quiz_rounds (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid,
  q_date date not null,
  question text not null,
  option_a text not null,
  option_b text not null,
  user_id uuid references auth.users(id) on delete cascade,
  choice text not null check (choice in ('a','b')),
  created_at timestamptz default now(),
  unique (couple_id, q_date, user_id)
);

-- RLS
alter table milestones enable row level security;
alter table daily_answers enable row level security;
alter table couple_meta enable row level security;
alter table moods enable row level security;
alter table greetings enable row level security;
alter table songlist enable row level security;
alter table watchlist enable row level security;
alter table quiz_rounds enable row level security;

create policy "ms_read" on milestones for select using (couple_id = my_couple_id());
create policy "ms_write" on milestones for insert with check (couple_id = my_couple_id());
create policy "ms_delete" on milestones for delete using (couple_id = my_couple_id());

create policy "da_read" on daily_answers for select using (couple_id = my_couple_id());
create policy "da_write" on daily_answers for insert with check (user_id = auth.uid() and couple_id = my_couple_id());

create policy "cm_read" on couple_meta for select using (couple_id = my_couple_id());
create policy "cm_write" on couple_meta for insert with check (couple_id = my_couple_id());
create policy "cm_update" on couple_meta for update using (couple_id = my_couple_id());

create policy "mo_read" on moods for select using (couple_id = my_couple_id());
create policy "mo_write" on moods for insert with check (user_id = auth.uid() and couple_id = my_couple_id());
create policy "mo_update" on moods for update using (user_id = auth.uid() and couple_id = my_couple_id());

create policy "gr_read" on greetings for select using (couple_id = my_couple_id());
create policy "gr_write" on greetings for insert with check (user_id = auth.uid() and couple_id = my_couple_id());

create policy "sl_read" on songlist for select using (couple_id = my_couple_id());
create policy "sl_write" on songlist for insert with check (couple_id = my_couple_id());
create policy "sl_delete" on songlist for delete using (couple_id = my_couple_id());

create policy "wl_read" on watchlist for select using (couple_id = my_couple_id());
create policy "wl_write" on watchlist for insert with check (couple_id = my_couple_id());
create policy "wl_update" on watchlist for update using (couple_id = my_couple_id());
create policy "wl_delete" on watchlist for delete using (couple_id = my_couple_id());

create policy "qr_read" on quiz_rounds for select using (couple_id = my_couple_id());
create policy "qr_write" on quiz_rounds for insert with check (user_id = auth.uid() and couple_id = my_couple_id());
