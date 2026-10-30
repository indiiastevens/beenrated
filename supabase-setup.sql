-- beenrated database setup
-- Paste this whole file into Supabase → SQL Editor → New query, then click Run. Run it once.

-- ---------- Tables ----------

create table public.courses (
  id          text primary key check (id ~ '^[A-Z]{2,8}-[A-Z0-9]{1,6}$'),
  dept        text not null check (dept ~ '^[A-Z]{2,8}$'),
  num         text not null check (num ~ '^[A-Z0-9]{1,6}$'),
  title       text not null check (char_length(title) between 1 and 90),
  attrs       text[] not null default '{}' check (cardinality(attrs) <= 12),
  created_at  timestamptz not null default now()
);

create table public.reviews (
  id          uuid primary key default gen_random_uuid(),
  course_id   text not null references public.courses(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  year        text not null check (year in ('1st year','2nd year','3rd year','4th year','Grad student')),
  difficulty  smallint not null check (difficulty between 1 and 5),
  work        smallint not null check (work between 1 and 5),
  exams       smallint not null check (exams between 1 and 5),
  attendance  smallint not null check (attendance between 1 and 5),
  again       smallint not null check (again between 1 and 5),
  body        text not null check (char_length(body) between 1 and 500),
  useful      text not null default '' check (char_length(useful) <= 100),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (course_id, user_id)               -- one review per person per class
);

-- ---------- Who counts as a Duke student ----------

create or replace function public.is_duke()
returns boolean language sql stable
as $$
  select coalesce(lower(auth.jwt() ->> 'email') like '%@duke.edu', false)
$$;

-- ---------- Classes: anyone reads, Duke students add and fix codes ----------

alter table public.courses enable row level security;

create policy "Anyone can read classes" on public.courses
  for select using (true);

create policy "Duke students can add classes" on public.courses
  for insert to authenticated with check (public.is_duke());

create policy "Duke students can fix codes" on public.courses
  for update to authenticated using (public.is_duke()) with check (public.is_duke());

revoke insert, update, delete on public.courses from anon;
revoke update on public.courses from authenticated;
grant update (attrs) on public.courses to authenticated;   -- only the codes can be edited, not the title

-- ---------- Reviews: nobody touches the table directly ----------
-- The table stores who wrote each review (so people can edit their own),
-- but that column is never exposed. Reads go through the view below,
-- writes go through the two functions below.

alter table public.reviews enable row level security;
revoke all on public.reviews from anon, authenticated;

create view public.public_reviews as
  select id, course_id, year, difficulty, work, exams, attendance, again,
         body, useful, created_at, updated_at,
         (user_id = auth.uid()) as mine
  from public.reviews;

grant select on public.public_reviews to anon, authenticated;

create or replace function public.submit_review(
  p_course_id text, p_year text,
  p_difficulty int, p_work int, p_exams int, p_attendance int, p_again int,
  p_body text, p_useful text
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_duke() then
    raise exception 'Sign in with your duke.edu email to post.';
  end if;
  insert into public.reviews (course_id, user_id, year, difficulty, work, exams, attendance, again, body, useful)
  values (p_course_id, auth.uid(), p_year, p_difficulty, p_work, p_exams, p_attendance, p_again,
          trim(p_body), coalesce(trim(p_useful), ''))
  on conflict (course_id, user_id) do update set
    year = excluded.year, difficulty = excluded.difficulty, work = excluded.work,
    exams = excluded.exams, attendance = excluded.attendance, again = excluded.again,
    body = excluded.body, useful = excluded.useful, updated_at = now();
end;
$$;

create or replace function public.delete_my_review(p_course_id text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  delete from public.reviews where course_id = p_course_id and user_id = auth.uid();
end;
$$;

revoke execute on function public.submit_review(text,text,int,int,int,int,int,text,text) from public, anon;
revoke execute on function public.delete_my_review(text) from public, anon;
grant execute on function public.submit_review(text,text,int,int,int,int,int,text,text) to authenticated;
grant execute on function public.delete_my_review(text) to authenticated;
