--! Previous: sha1:86782d5e69550986b23564bfe81be46247ab2372
--! Hash: sha1:338b2b896ad8bf6d7185d782b98fec285267e3e3

----------------
-- I had a change of heart, and I want to use an eg_hidden
-- schema similar to graphile starter.
----------------
drop schema if exists eg_hidden cascade;
create schema eg_hidden;
revoke all on schema eg_hidden from public;
grant usage on schema eg_hidden
    to :DATABASE_MIGRATOR;


---------------------------
-- We're going to save sessions in postgres for now.
-- Likely better to save them in somewhere like redis going forward
---------------------------
drop table if exists eg_private.session;
create table eg_private.session (
    id              text            primary key,
    user_id         uuid            not null references eg_public.user(id) on delete cascade,
    expires_at      timestamptz     not null
);

create index on eg_private.session(user_id);

create function eg_hidden.initiate_session(
    session_id text,
    user_id uuid
) returns eg_private.session as $$
    insert into eg_private.session (
        id,
        user_id,
        expires_at
    ) values (
        session_id,
        user_id,
        now() + interval '30 days'
    ) returning *;
$$
language sql
volatile
strict
security definer 
set search_path to 'extensions';

create function eg_hidden.user_id_by_session_id(
    session_id text
) returns uuid as $$
    select
        u.id
    from eg_private.session s
    join eg_public.user u on u.id = s.user_id
    where s.id = session_id
        and s.expires_at > now();
$$
language sql
stable
strict
security definer 
set search_path to 'extensions';


------------------------------------
-- We have to make some changes to the login flow to support
-- adding the reference to the sesion
--
-- Also, I added the login flow functions to eg_public
-- originally. I decided I want them in eg_hidden
------------------------------------
alter table eg_private.login_flow
    drop column if exists user_id;

drop function if exists eg_public.srp_creds_by_email;
drop type if exists eg_public.srp_creds;
drop function if exists eg_public.save_login_flow;
drop function if exists eg_public.retrieve_login_flow;

alter table eg_private.login_flow
    add column user_id uuid not null references eg_public.user(id) on delete cascade;
create index on eg_private.login_flow(user_id);

drop function if exists eg_hidden.srp_creds_by_email;
drop type if exists eg_hidden.srp_creds;
create type eg_hidden.srp_creds as (
    id uuid,
    salt text,
    verifier text
);
create function eg_hidden.srp_creds_by_email(
    user_email citext
) returns eg_hidden.srp_creds as $$
    select
        u.id,
        uli.salt,
        us.verifier
    from eg_public.user u
    join eg_public.user_login_info uli on u.id = uli.user_id
    join eg_private.user_secrets us on u.id = us.user_id
    where u.email = user_email;
$$
language sql
volatile
strict
security definer 
set search_path to 'extensions';

drop function if exists eg_hidden.save_login_flow;
create function eg_hidden.save_login_flow(
    user_id uuid,
    serialized_server_state text
) returns uuid as $$
    insert into eg_private.login_flow(
        serialized_server_state,
        expires_at,
        user_id
    ) values (
        serialized_server_state,
        now() + interval '1 minute',
        user_id
    ) returning id;
$$
language sql
volatile
strict
security definer 
set search_path to 'extensions';

drop function if exists eg_hidden.retrieve_login_flow;
create function eg_hidden.retrieve_login_flow(
    login_flow_id uuid
) returns eg_private.login_flow as $$
    select *
    from eg_private.login_flow
    where id = login_flow_id
        and now() < expires_at;
$$
language sql
stable
strict
security definer 
set search_path to 'extensions';
