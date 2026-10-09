-- Applied to funihyfxlliwnpthamdi and verified with an authenticated
-- INSERT ... RETURNING mode,max_players inside a rolled-back transaction.
begin;
alter table public.game_rooms drop constraint if exists game_rooms_mode_check;
alter table public.game_rooms add constraint game_rooms_mode_check
  check (mode in ('ffa', 'tdm'));
commit;
