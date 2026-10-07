-- Lanterne : serveur de synchronisation (Supabase)
-- À coller dans Supabase → SQL Editor → New query → Run. Peut être relancé sans risque.

create table if not exists public.lanterne_docs (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  key text not null, data jsonb, mtime bigint not null default 0,
  deleted boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (user_id, key));
create index if not exists lanterne_docs_updated on public.lanterne_docs (user_id, updated_at);
alter table public.lanterne_docs enable row level security;
drop policy if exists "lanterne own rows" on public.lanterne_docs;
create policy "lanterne own rows" on public.lanterne_docs for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
grant select, insert, update, delete on public.lanterne_docs to authenticated;

create or replace function public.lanterne_touch() returns trigger language plpgsql as $$
begin if tg_op = 'UPDATE' and new.mtime < old.mtime then return old; end if;
  new.updated_at := clock_timestamp(); return new; end $$;
drop trigger if exists lanterne_touch on public.lanterne_docs;
create trigger lanterne_touch before insert or update on public.lanterne_docs
  for each row execute function public.lanterne_touch();

-- Suppression de compte depuis l'app (chacun ne peut supprimer que le sien)
create or replace function public.lanterne_delete_me() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.lanterne_docs where user_id = auth.uid();
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.lanterne_delete_me() from public, anon;
grant execute on function public.lanterne_delete_me() to authenticated;

-- ─────────────────────────────────────────────────────────────
-- ADMIN (à lancer à la main, seulement si besoin) :
-- Remettre un mot de passe à un ami qui l'a oublié. Remplace l'e-mail et le mot de passe, puis Run.
-- Ensuite il se connecte avec ce mot de passe et entre son code de secours dans l'app.
--
-- update auth.users set encrypted_password = extensions.crypt('NouveauMotDePasse', extensions.gen_salt('bf'))
--   where email = 'pote@exemple.com';
