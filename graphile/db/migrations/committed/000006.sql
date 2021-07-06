--! Previous: sha1:338b2b896ad8bf6d7185d782b98fec285267e3e3
--! Hash: sha1:55afa73e4c4683899e64010f1133387f1d2c83b4

-----------------------
-- We're going to change the session retrieval function to
-- retrieve all necessary values for postgraphile's pg_settings
-- to control RLS
-----------------------
drop function if exists eg_hidden.user_id_by_session_id;
drop function if exists eg_hidden.user_by_session_id;
create function eg_hidden.user_by_session_id(
    session_id text
) returns eg_public.user as $$
    select u.*
    from eg_private.session s
    join eg_public.user u
        on u.id = s.user_id
    where s.id = session_id;
$$
language sql
stable
strict
security definer 
set search_path to 'extensions';


----------------------
-- As a POC for the user id setting, we'll create a viewer
-- GQL query. And the current_user_id function will be very
-- useful for RLS in the future.
----------------------
drop function if exists eg_hidden.current_user_id;
create function eg_hidden.current_user_id()
returns uuid as $$
    select nullif(current_setting('user.id', true), '') :: uuid;
$$
language sql
stable
security invoker;

drop function if exists eg_public.viewer;
create function eg_public.viewer()
returns eg_public.user as $$
    select *
    from eg_public.user
    where id = eg_hidden.current_user_id();
$$
language sql
stable
security invoker;


---------------------
-- And now, because we are finally switching to use the eg_api
-- role in postgraphile, we need to do some permissioning cleanup
-- to get the viewer query to work. I'll do more thorough grants
-- and policies in a later patch
---------------------
grant usage on schema eg_hidden
    to :API_ROLE, eg_student, eg_teacher, eg_anon;
grant select on eg_public.user
    to eg_student, eg_teacher;
