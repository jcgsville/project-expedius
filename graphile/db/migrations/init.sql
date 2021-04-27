begin;

-- I'm going to go with the pattern where I drop the default public schema and empty
-- the search path, requiring qualified references for every query. It's verbose,
-- but it strikes me as the most safe.
drop schema if exists public;
alter database :DATABASE_NAME set search_path to '';

create schema if not exists extensions;
create extension if not exists plpgsql with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

commit;
