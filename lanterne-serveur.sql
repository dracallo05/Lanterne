-- Lanterne : synchronisation des aventures entre appareils
-- À coller dans Supabase → SQL Editor → New query → Run

create table if not exists public.lanterne_docs (
  user_id    uuid not null default auth.uid() references auth.users on delete cascade,
  key        text not null,
  data       jsonb,
  mtime      bigint not null default 0,
  deleted    boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, key)
);

create index if not exists lanterne_docs_updated on public.lanterne_docs (user_id, updated_at);

-- Chaque compte ne voit et ne modifie que ses propres données
alter table public.lanterne_docs enable row level security;
drop policy if exists "lanterne own rows" on public.lanterne_docs;
create policy "lanterne own rows" on public.lanterne_docs
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete on public.lanterne_docs to authenticated;

-- La version la plus récente gagne, et on date chaque modification
create or replace function public.lanterne_touch() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.mtime < old.mtime then
    return old;
  end if;
  new.updated_at := clock_timestamp();
  return new;
end $$;

drop trigger if exists lanterne_touch on public.lanterne_docs;
create trigger lanterne_touch before insert or update on public.lanterne_docs
  for each row execute function public.lanterne_touch();
