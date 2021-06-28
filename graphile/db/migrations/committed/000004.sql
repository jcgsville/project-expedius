--! Previous: sha1:458841bf8f2ef955d033a5e04b092a8ac3bce496
--! Hash: sha1:86782d5e69550986b23564bfe81be46247ab2372

----------------
-- We're going to use SRP authentication to keep the password client
-- side. No passwords will ever even be sent to the server, so there's
-- no opportunity to log them. We will store the verifier in a separate
-- table not exposed to the API.
----------------
alter table eg_public.user
    drop constraint if exists user_id_secrets_fkey;
drop table if exists eg_private.user_secrets;

create table eg_private.user_secrets (
    user_id         uuid            primary key references eg_public.user(id) on delete cascade,
    verifier        text            not null
);


----------------
-- We can ensure that a user always has secrets by adding a foreign key
-- constraint. By making it on delete restrict, we can prevent user secrets
-- from being deleted except by deleting the user.
----------------
alter table eg_public.user
    add constraint user_id_secrets_fkey
        foreign key (id)
        references eg_private.user_secrets(user_id)
        on delete restrict;


----------------
-- For some reason, I forgot to add a unique constraint on user email
----------------
alter table eg_public.user
    drop constraint if exists unique_email;
alter table eg_public.user
    add constraint unique_email unique(email);


----------------
-- Graphile suggests using an app_hidden schema. I think I prefer to put
-- everything accessible to the API in eg_public and use smart tags to
-- curate what is hidden and what isn't. Thus, user_login_info will be
-- in eg_public. It'll have the same foreign key treatment as
-- eg_private.user_secrets with an extra foreign key constraint on email
-- to ensure that the email here lines up with the email in eg_public.user.
-- I think that having email denormalized here will be helpful for RLS
-- once I add it, but I may be wrong
----------------
alter table eg_public.user
    drop constraint if exists user_id_login_info_fkey;
drop table if exists eg_public.user_login_info;
alter table eg_public.user
    drop constraint if exists unique_email_id;

-- This is only needed to do the fkey trick to enforce the denormalization
alter table eg_public.user
    add constraint unique_email_id unique(email, id);

create table eg_public.user_login_info (
    user_id         uuid            primary key references eg_public.user(id) on delete cascade,
    email           citext          not null,
    salt            text            not null,
    foreign key (user_id, email) references eg_public.user(id, email) on delete cascade
);

create index on eg_public.user_login_info(email);

alter table eg_public.user
    add constraint user_id_login_info_fkey
        foreign key (id)
        references eg_public.user_login_info(user_id)
        on delete restrict;


----------------
-- Before initiating the login flow, the user will need
-- the salt for the email. This is the only way we'll be
-- exposing the info in eg_public.user_login_flow
----------------
drop function if exists eg_public.user_login_salt;
create function eg_public.user_login_salt(
    user_email citext
) returns text as $$
    select salt
    from eg_public.user_login_info
    where email = user_email;
$$ language sql stable security invoker;


----------------
-- Now, we'll create a custom mutation for signing up. Because
-- USER_WITH_EMAIL_EXISTS is an expected error condition, we'll include
-- it in the payload as opposed to raising an exception. Setting the
-- function as strict makes all input required.
--
-- Note that many of the following functions related to auth will be
-- security definer to access things in the private schema
--
-- Though I'm not certain of this, I'm pretty sure that 2 perfectly timed
-- sign up requests with the same email could result in both getting past
-- the if exists check. However the constraints on the table would only allow
-- one of the inserts to succeed.
----------------
drop function if exists eg_public.sign_up;
drop type if exists eg_public.sign_up_result;

create type eg_public.sign_up_result as enum(
    'USER_WITH_EMAIL_EXISTS',
    'SUCCESS'
);

create function eg_public.sign_up(
    email citext,
    user_type eg_public.user_type,
    verifier text,
    salt text
) returns eg_public.sign_up_result as $$
declare
    _email citext := email;
begin
    if exists (select 1 from eg_public.user u where u.email = _email)
    then return 'USER_WITH_EMAIL_EXISTS';
    end if;

    with inserted_user as (
        insert into eg_public.user (
            email,
            name,
            user_type
        ) values (
            _email,
            -- We'll get back to names. I'm not sure I want them on public.user
            -- and I'm not sure I want them to be required.
            'Bob',
            user_type
        ) returning *
    ), secrets as (
        insert into eg_private.user_secrets (
            user_id,
            verifier
        ) select
            u.id,
            verifier
        from inserted_user u
        returning *
    ) insert into eg_public.user_login_info (
        user_id,
        email,
        salt
    ) select
        u.id,
        u.email,
        salt
    from inserted_user u;

    return 'SUCCESS';
end;
$$
language plpgsql
volatile
strict
security definer 
set search_path to 'extensions';


----------------
-- We need a place to save the state of the SRP server
-- for each login flow and functions to save and retrieve
-- the login flow.
--
-- This should absolutely be stored somewhere else like redis,
-- but I'd rather go with the db for now to only manage
-- one data storage location.
----------------
drop table if exists eg_private.login_flow;
create table eg_private.login_flow (
    id uuid primary key default uuid_generate_v4(),
    serialized_server_state text not null,
    expires_at timestamptz not null
);


-- I don't love that the verifer is returned from this function,
-- but I'm not really into the idea of writing a postgres version
-- of the SRP6a library. Maybe a fun future project?
drop function if exists eg_public.srp_creds_by_email;
drop type if exists eg_public.srp_creds;
create type eg_public.srp_creds as (
    salt text,
    verifier text
);
create function eg_public.srp_creds_by_email(
    user_email citext
) returns eg_public.srp_creds as $$
    select
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

drop function if exists eg_public.save_login_flow;
create function eg_public.save_login_flow(
    serialized_server_state text
) returns uuid as $$
    insert into eg_private.login_flow(
        serialized_server_state,
        expires_at
    ) values (
        serialized_server_state,
        now() + interval '1 minute'
    ) returning id;
$$
language sql
volatile
strict
security definer 
set search_path to 'extensions';

drop function if exists eg_public.retrieve_login_flow;
create function eg_public.retrieve_login_flow(
    login_flow_id uuid
) returns text as $$
    select serialized_server_state
    from eg_private.login_flow
    where id = login_flow_id
        and now() < expires_at;
$$
language sql
stable
strict
security definer 
set search_path to 'extensions';


----------------
-- We don't want data lingering in the login_flow table for
-- forever once it's "expired", so we'll create a trigger to
-- delete the old flows whenever a new one is inserted. If we
-- used a different data store with a built-in expiry, we should
-- definitely use that.
----------------
drop trigger if exists _900_delete_expired
    on eg_private.login_flow;
drop function if exists eg_private.tg__login_flow__delete_expired;

create function eg_private.tg__login_flow__delete_expired()
returns trigger as $$
begin
    delete from eg_private.login_flow
    where expires_at < now() - interval '30 seconds';

    return new;
end;
$$ language plpgsql
volatile
security definer
set search_path to 'extensions';

create trigger _900_delete_expired
    after insert
    on eg_private.login_flow
    for each statement
    execute procedure eg_private.tg__login_flow__delete_expired();
