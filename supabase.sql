-- Pealkirjajaht: ühine edetabel (Supabase)
-- Käivita see Supabase'i projektis: SQL Editor → New query → kleebi → Run.
-- Seda võib turvaliselt mitu korda käivitada.

-- 1) Tabel: iga mängija iga päeva esimene tulemus (üks rida mängija ja päeva kohta)
create table if not exists public.scores (
  player_id  uuid        not null,
  play_date  date        not null,
  name       text        not null check (char_length(name) between 1 and 24),
  score      integer     not null check (score >= 0),
  correct    integer     not null check (correct >= 0),
  total      integer     not null check (total between 1 and 30 and correct <= total),
  grid       text        not null default '',
  created_at timestamptz not null default now(),
  primary key (player_id, play_date)
);
create index if not exists scores_play_date_idx on public.scores (play_date);

-- 2) Otsene ligipääs tabelile on keelatud; mäng kasutab ainult allolevaid funktsioone.
alter table public.scores enable row level security;
revoke all on public.scores from anon, authenticated;

-- Abifunktsioon: suurim võimalik skoor n küsimuse korral (sama valem mis mängus)
create or replace function public.pj_max_score(n integer)
returns integer language sql immutable as $$
  select coalesce(sum(1000 * (1 + 0.25 * least(i, 4)))::integer, 0)
  from generate_series(0, n - 1) as i
$$;

-- Abifunktsioon: nime puhastamine
create or replace function public.pj_clean_name(p text)
returns text language sql immutable as $$
  select left(btrim(regexp_replace(regexp_replace(coalesce(p, ''), '[[:cntrl:]]', '', 'g'), '\s+', ' ', 'g')), 24)
$$;

-- 3) Tulemuse salvestamine. Tagastab true, kui tulemus läks kirja; false, kui selle päeva tulemus oli juba olemas.
create or replace function public.submit_score(
  p_player uuid, p_date date, p_name text,
  p_score integer, p_correct integer, p_total integer, p_grid text
) returns boolean
language plpgsql security definer set search_path = public as $$
declare
  today date := (now() at time zone 'Europe/Tallinn')::date;
  v_name text := public.pj_clean_name(p_name);
  v_grid text := coalesce(p_grid, '');
  n integer;
begin
  if p_player is null then raise exception 'mängija puudub'; end if;
  -- arvesse lähevad ainult tänane ja eilne väljaanne (eilne, et südaööl mängija ei jääks ilma)
  if p_date is null or p_date not in (today, today - 1) then raise exception 'vale kuupäev'; end if;
  if v_name = '' then raise exception 'nimi puudub'; end if;
  if p_total is null or p_total < 1 or p_total > 30
     or p_correct is null or p_correct < 0 or p_correct > p_total then
    raise exception 'vigased andmed';
  end if;
  if p_score is null or p_score < 0 or p_score > public.pj_max_score(p_total) then
    raise exception 'võimatu skoor';
  end if;
  if v_grid !~ '^(ok|half|bad|to)(,(ok|half|bad|to))*$'
     or array_length(string_to_array(v_grid, ','), 1) <> p_total then
    raise exception 'vigane ruudustik';
  end if;

  insert into public.scores (player_id, play_date, name, score, correct, total, grid)
  values (p_player, p_date, v_name, p_score, p_correct, p_total, v_grid)
  on conflict (player_id, play_date) do nothing;
  get diagnostics n = row_count;

  -- edetabel näitab mängija viimast nime
  update public.scores set name = v_name where player_id = p_player and name <> v_name;
  return n > 0;
end $$;

-- 4) Nime muutmine (kõigil mängija ridadel)
create or replace function public.set_player_name(p_player uuid, p_name text)
returns void
language plpgsql security definer set search_path = public as $$
declare v_name text := public.pj_clean_name(p_name);
begin
  if p_player is null or v_name = '' then raise exception 'vigased andmed'; end if;
  update public.scores set name = v_name where player_id = p_player and name <> v_name;
end $$;

-- 5) Edetabel. p_period: 'day' (see päev), 'week' (7 päeva kuni p_date), 'all' (kõik ajad).
--    Tagastab esikümne (p_limit) ja lisaks küsija enda rea, kui ta on tabelis allpool.
--    Mängijate ID-sid välja ei anta.
create or replace function public.leaderboard(
  p_date date, p_period text default 'day', p_player uuid default null, p_limit integer default 10
) returns table (pos integer, name text, score bigint, games integer, correct bigint, total bigint, is_me boolean)
language sql stable security definer set search_path = public as $$
  with filtered as (
    select * from public.scores s
    where case coalesce(p_period, 'day')
            when 'week' then s.play_date between p_date - 6 and p_date
            when 'all'  then s.play_date <= p_date
            else s.play_date = p_date
          end
  ),
  agg as (
    select player_id,
           (array_agg(name order by created_at desc))[1] as name,
           sum(score)::bigint as score, count(*)::integer as games,
           sum(correct)::bigint as correct, sum(total)::bigint as total,
           min(created_at) as first_at
    from filtered group by player_id
  ),
  ranked as (
    select *, (rank() over (order by score desc))::integer as pos,
              row_number() over (order by score desc, first_at) as rn
    from agg
  )
  select pos, name, score, games, correct, total, coalesce(player_id = p_player, false) as is_me
  from ranked
  where rn <= least(greatest(coalesce(p_limit, 10), 1), 50) or player_id = p_player
  order by rn
$$;

-- 6) Õigused: avalik võti (anon) saab ainult neid kolme funktsiooni kutsuda
revoke execute on function public.submit_score(uuid, date, text, integer, integer, integer, text) from public;
revoke execute on function public.set_player_name(uuid, text) from public;
revoke execute on function public.leaderboard(date, text, uuid, integer) from public;
grant execute on function public.submit_score(uuid, date, text, integer, integer, integer, text) to anon, authenticated;
grant execute on function public.set_player_name(uuid, text) to anon, authenticated;
grant execute on function public.leaderboard(date, text, uuid, integer) to anon, authenticated;
