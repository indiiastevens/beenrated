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
  id               uuid primary key default gen_random_uuid(),
  course_id        text not null references public.courses(id) on delete cascade,
  user_id          uuid not null references auth.users(id) on delete cascade,
  year             text check (year in ('1st year','2nd year','3rd year','4th year','Grad student')),
  -- 1-5 scales, all optional
  again            smallint check (again between 1 and 5),
  taught           smallint check (taught between 1 and 5),
  interesting      smallint check (interesting between 1 and 5),
  workload         smallint check (workload between 1 and 5),
  exams            smallint check (exams between 1 and 5),
  assignments      smallint check (assignments between 1 and 5),
  participation    smallint check (participation between 1 and 5),
  attendance       smallint check (attendance between 1 and 5),
  -- optional descriptions
  workload_note    text not null default '' check (char_length(workload_note) <= 300),
  assessment_note  text not null default '' check (char_length(assessment_note) <= 300),
  attendance_note  text not null default '' check (char_length(attendance_note) <= 300),
  -- yes / no questions (null = not answered)
  group_work       boolean,
  background       boolean,
  background_note  text not null default '' check (char_length(background_note) <= 300),
  -- why they took it
  reasons          text[] not null default '{}' check (cardinality(reasons) <= 6),
  reason_note      text not null default '' check (char_length(reason_note) <= 200),
  -- in their words
  body             text not null default '' check (char_length(body) <= 500),
  useful           text not null default '' check (char_length(useful) <= 100),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (course_id, user_id),                                       -- one review per person per class
  check (num_nonnulls(again, taught, interesting, workload, exams, assignments, participation, attendance, group_work, background) > 0
         or char_length(body) > 0)                                    -- not completely empty
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

create or replace view public.public_reviews as
  select id, course_id, year, again, taught, interesting, workload, exams, assignments, participation, attendance,
         workload_note, assessment_note, attendance_note,
         group_work, background, background_note, reasons, reason_note,
         body, useful, created_at, updated_at,
         (user_id = auth.uid()) as mine
  from public.reviews;

grant select on public.public_reviews to anon, authenticated;

create or replace function public.submit_review(p_course_id text, p jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_duke() then
    raise exception 'Sign in with your duke.edu email to post.';
  end if;
  insert into public.reviews (
    course_id, user_id, year, again, taught, interesting, workload, exams, assignments, participation, attendance,
    workload_note, assessment_note, attendance_note,
    group_work, background, background_note, reasons, reason_note, body, useful)
  values (
    p_course_id, auth.uid(), nullif(p->>'year', ''),
    (p->>'again')::smallint, (p->>'taught')::smallint, (p->>'interesting')::smallint, (p->>'workload')::smallint,
    (p->>'exams')::smallint, (p->>'assignments')::smallint, (p->>'participation')::smallint, (p->>'attendance')::smallint,
    coalesce(trim(p->>'workload_note'), ''), coalesce(trim(p->>'assessment_note'), ''), coalesce(trim(p->>'attendance_note'), ''),
    (p->>'group_work')::boolean, (p->>'background')::boolean, coalesce(trim(p->>'background_note'), ''),
    coalesce(array(select jsonb_array_elements_text(coalesce(p->'reasons', '[]'::jsonb))), '{}'),
    coalesce(trim(p->>'reason_note'), ''),
    coalesce(trim(p->>'body'), ''), coalesce(trim(p->>'useful'), ''))
  on conflict (course_id, user_id) do update set
    year = excluded.year, again = excluded.again, taught = excluded.taught, interesting = excluded.interesting,
    workload = excluded.workload, exams = excluded.exams, assignments = excluded.assignments,
    participation = excluded.participation, attendance = excluded.attendance,
    workload_note = excluded.workload_note, assessment_note = excluded.assessment_note, attendance_note = excluded.attendance_note,
    group_work = excluded.group_work, background = excluded.background, background_note = excluded.background_note,
    reasons = excluded.reasons, reason_note = excluded.reason_note,
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

revoke execute on function public.submit_review(text, jsonb) from public, anon;
revoke execute on function public.delete_my_review(text) from public, anon;
grant execute on function public.submit_review(text, jsonb) to authenticated;
grant execute on function public.delete_my_review(text) to authenticated;
