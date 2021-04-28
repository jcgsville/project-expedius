begin;
------------
-- The prerequisites to running this script are
-- 1 - create login role for migrator
-- 2 - create database with migrator as owner
-- 3 - create login role for api user
--
-- This script needs to be run as a superuser
--
-- This script should be idempotent
-------------
grant connect on database :DATABASE_NAME to :API_ROLE;

-- I'm going to go with the pattern where I drop the default public schema
drop schema if exists public;

-- We're going to install extensions to a separate schema, and include only that
-- schema in the search path. This will require qualified references for every
-- application query. It's verbose, but it strikes me as the safest and cleanest
create schema if not exists extensions;
create extension if not exists plpgsql with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;
-- This is required for every new role created
grant usage on schema extensions to
    :DATABASE_MIGRATOR, :API_ROLE;
alter database :DATABASE_NAME set search_path to 'extensions';

-- Still trying to determine if this is overkill to separate the role creation
-- from the migrations. To be able to create them in the migrations, I would need
-- super user permissions. Is it so bad to run the migrations with super user
-- permissions?
create function pg_temp.create_role_if_not_exists(
    role_name name
) returns void as $$
begin
    if not exists (
        select from pg_catalog.pg_roles
        where  rolname = role_name
    ) then execute format('create role %I', role_name);
    end if;
end;
$$ language plpgsql volatile security invoker;

select pg_temp.create_role_if_not_exists('eg_anon');
select pg_temp.create_role_if_not_exists('eg_student');
select pg_temp.create_role_if_not_exists('eg_teacher');

grant usage on schema extensions to
    eg_anon, eg_student, eg_teacher;

grant eg_anon, eg_student, eg_teacher to :API_ROLE;


commit;
