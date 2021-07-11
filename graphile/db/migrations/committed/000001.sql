--! Previous: -
--! Hash: sha1:dcf817243acccafcec41e87a495276e1a003fcc4

drop schema if exists eg_public cascade;
create schema eg_public;
revoke all on schema eg_public from public;
grant usage on schema eg_public
    to eg_anon, eg_student, eg_teacher;


drop schema if exists eg_private cascade;
create schema eg_private;
revoke all on schema eg_private from public;


drop schema if exists eg_hidden cascade;
create schema eg_hidden;
revoke all on schema eg_hidden from public;
grant usage on schema eg_hidden
    to :API_ROLE, eg_student, eg_teacher, eg_anon;


-- The desired end state is that functions in eg_public have to be
-- specifically granted to roles. However if you specify..
alter default privileges
    revoke execute on functions
    from public;
alter default privileges in schema eg_hidden
    grant execute on functions
    to eg_anon, eg_student, eg_teacher;
alter default privileges in schema extensions
    grant execute on functions
    to eg_anon, eg_student, eg_teacher;


-- There will be other things in the user object
-- graph with different permission characteristics.
-- We'll start with the basic user row
create type eg_public.user_type as enum('STUDENT', 'TEACHER');
create table eg_public.user (
    id uuid primary key default uuid_generate_v4(),
    -- This is a super simple regex to just make sure it's vaguely
    -- close to a real email
    email citext not null check (email ~ '^.+@.+\..+$') unique,
    user_type eg_public.user_type not null,
    salt text not null
);


-- Let's make the user_type column un-editable. We could achieve the
-- same thing with role permissions by not granting update of the column
-- to any roles, but when it's not expensive to do so, I like to enforce
-- things as close to the data as possible
--
-- It's a bit weird that the condition that warrants the error lives in
-- the trigger definition and not the function definition, but I have
-- a suspicion this is more performant. Blog post idea!
create function eg_private.tg__user__type_uneditable()
returns trigger as $$
begin
    raise 'eg_public.user.user_type cannot be changed';
    return new;
end;
$$ language plpgsql security definer;
create trigger _500_user_type_uneditable
    before update on eg_public.user
    for each row
    when (old.user_type is distinct from new.user_type)
    execute procedure eg_private.tg__user__type_uneditable();


-- Now, let's create a class table. It's mostly just a placeholder for now.
create table eg_public.class (
    id uuid primary key default uuid_generate_v4(),
    name text not null check (length(name) > 2 and length(name) < 100),
    teacher_id uuid not null references eg_public.user(id) on delete restrict
);
create index class_teacher_id
    on eg_public.class(teacher_id);


-- There's no built-in way to check a column on the teacher being
-- referenced by the teacher_id table, so we'll have to do these checks
-- separately.
--
-- Normally, we'd worry about race conditions because the user_type
-- column could be updated in a concurrent session, and this trigger
-- would succeed. In this case, since we prevented the user column
-- from being updated, we know it is safe.
create function eg_private.tg__class__teacher_correct_user_type()
returns trigger as $$
declare
    teacher_user_type eg_public.user_type = (
        select user_type
        from eg_public.user
        where id = new.teacher_id
    );
begin
    if new.teacher_id is not null and teacher_user_type != 'TEACHER'
    then raise 'eg_public.class.teacher_id must point to a user with type TEACHER';
    end if;
    
    return new;
end;
$$ language plpgsql security definer;

create trigger _500_teacher_correct_user_type_insert
    before insert on eg_public.class
    for each row
    execute procedure eg_private.tg__class__teacher_correct_user_type();
create trigger _501_teacher_correct_user_type_update
    before update on eg_public.class
    for each row
    when (old.teacher_id is distinct from new.teacher_id)
    execute procedure eg_private.tg__class__teacher_correct_user_type();


-- We'll store any user secrets in a separate table in the private
-- schema. For now, it'll just be the SRP Verifier
create table eg_private.user_secrets (
    id          uuid            primary key references eg_public.user(id) on delete cascade,
    verifier    text            not null
);


-- We can ensure that a user always has secrets by adding a foreign key
-- constraint. By making it on delete restrict, we can prevent user secrets
-- from being deleted except by deleting the user.
alter table eg_public.user
    add constraint user_id_secrets_fkey
        foreign key (id)
        references eg_private.user_secrets(id)
        on delete restrict;


-- We'll create a function to expose a custom mutation to sign up a user.
-- User with email exists is an expected case that we would need to be able
-- to handle spcifically in the UI. Thus, it should be returned instead of
-- being raised in an exception.
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
            user_type,
            salt
        ) values (
            _email,
            user_type,
            salt
        ) returning *
    ) insert into eg_private.user_secrets (
        id,
        verifier
    ) select
        u.id,
        verifier
    from inserted_user u;

    return 'SUCCESS';
end;
$$
language plpgsql
volatile
strict
security definer 
set search_path to 'extensions';
grant execute on function eg_public.sign_up to eg_anon;


-- We need a place to save the state of the SRP server
-- for each login flow and functions to save and retrieve
-- the login flow.
--
-- This should absolutely be stored somewhere else like redis,
-- but I'd rather go with the db for now to only manage
-- one data storage location.
create table eg_private.login_flow (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references eg_public.user(id) on delete cascade,
    serialized_server_state text not null,
    expires_at timestamptz not null
);
create index on eg_private.login_flow(user_id);


-- Any time a new user logs in, we'll clean up the old rows
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


-- Just like the login flows, we're going to save sessions in postgres for now.
create table eg_private.session (
    id              text            primary key,
    user_id         uuid            not null references eg_public.user(id) on delete cascade,
    expires_at      timestamptz     not null
);
create index on eg_private.session(user_id);


-- Util functions in use by the postgraphile plugins for the login flow
-- and session management.
--
-- We could use the existing user query to expose the salt for the beginning
-- of the login flow, but this exposes less information and making it
-- security definer allows us to not give anon access to eg_public.user
create function eg_public.user_login_salt(
    user_email citext
) returns text as $$
    select salt
    from eg_public.user
    where email = user_email;
$$
language sql
stable
strict
security definer 
set search_path to 'extensions';
grant execute on function eg_public.user_login_salt to eg_anon;

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
        u.salt,
        us.verifier
    from eg_public.user u
    join eg_private.user_secrets us on u.id = us.id
    where u.email = user_email;
$$
language sql
stable
strict
security definer 
set search_path to 'extensions';

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


-- Really helpful to have a viewer query to answer the question
-- "Who am I?". Also, eg_hidden.current_user_id is going to be
-- used by eventual RLS policies.
create function eg_hidden.current_user_id()
returns uuid as $$
    select nullif(current_setting('user.id', true), '') :: uuid;
$$
language sql
stable
security invoker;

create function eg_public.viewer()
returns eg_public.user as $$
    select *
    from eg_public.user
    where id = eg_hidden.current_user_id();
$$
language sql
stable
security invoker;


-- We'll jump into RLS in a later patch. For now just table grants.
grant select on eg_public.user
    to eg_student, eg_teacher;
