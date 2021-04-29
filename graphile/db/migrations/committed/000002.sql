--! Previous: sha1:9438e317a55dd75cb0bf7adbdd77827e5f9edd60
--! Hash: sha1:9d1d86577270630137e5285aa53b1e1f44ca1d2c

-- First, a little more setup for the eg_public schema
revoke all on schema eg_public from public;
grant usage on schema eg_public
    to eg_student, eg_teacher, :DATABASE_MIGRATOR;
alter default privileges in schema eg_public
    grant execute on functions to eg_student, eg_teacher;

-- Let's create our first table to expose on the API
drop table if exists eg_public.user;
create table eg_public.user (
    id uuid primary key default uuid_generate_v4(),
    -- This is a super simple regex to just make sure it's vaguely
    -- close to a real email
    email citext not null check (email ~ '^.+@.+\..+$'),
    name text not null check (length(name) > 1)
);
