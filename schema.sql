-- QR Attendance System: full database schema (run once in the Supabase SQL Editor)

-- Tables
create table students (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  roll_no text unique,
  pin text
);

create table classes (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  class_date date not null default current_date,
  closes_at timestamptz
);

create table attendance (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  status text not null check (status in ('present','absent')),
  device_id text,
  unique (student_id, class_id)
);

-- One phone can mark only one student per class
create unique index one_device_per_class
  on attendance(class_id, device_id) where device_id is not null;

create table class_tokens (
  id bigint generated always as identity primary key,
  class_id uuid not null references classes(id) on delete cascade,
  token text not null,
  created_at timestamptz not null default now()
);

-- Row Level Security: locked by default
alter table students enable row level security;
alter table classes enable row level security;
alter table attendance enable row level security;
alter table class_tokens enable row level security;

-- Logged-in teachers can do everything
create policy "teachers all" on students for all to authenticated using (true) with check (true);
create policy "teachers all" on classes for all to authenticated using (true) with check (true);
create policy "teachers all" on attendance for all to authenticated using (true) with check (true);
create policy "teachers all" on class_tokens for all to authenticated using (true) with check (true);

-- Public (students) can only call these two functions

create or replace function get_class(p_id uuid)
returns table(subject text, class_date date, is_open boolean)
language sql security definer set search_path = public as $$
  select c.subject, c.class_date, coalesce(c.closes_at > now(), false)
  from classes c where c.id = p_id;
$$;

create or replace function mark_present(
  p_class uuid, p_roll text, p_pin text, p_device text, p_token text)
returns text
language plpgsql security definer set search_path = public as $$
declare s students%rowtype;
begin
  if not exists (select 1 from classes
      where id = p_class and closes_at > now()) then
    raise exception 'closed';
  end if;
  if not exists (select 1 from class_tokens
      where class_id = p_class and token = p_token
      and created_at > now() - interval '60 seconds') then
    raise exception 'expired';
  end if;
  select * into s from students where roll_no = p_roll and pin = p_pin;
  if not found then raise exception 'bad_login'; end if;
  if exists (select 1 from attendance
      where class_id = p_class and device_id = p_device
      and student_id <> s.id) then
    raise exception 'device_used';
  end if;
  insert into attendance(student_id, class_id, status, device_id)
  values (s.id, p_class, 'present', p_device)
  on conflict (student_id, class_id)
  do update set status = 'present', device_id = p_device;
  return s.name;
end $$;

grant execute on function get_class(uuid) to anon, authenticated;
grant execute on function mark_present(uuid, text, text, text, text) to anon, authenticated;
