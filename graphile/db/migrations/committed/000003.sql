--! Previous: sha1:9d1d86577270630137e5285aa53b1e1f44ca1d2c
--! Hash: sha1:458841bf8f2ef955d033a5e04b092a8ac3bce496

----------------
-- We're going to need the private schema in which to add triggers
-- for this patch. Let's add it now
----------------
drop schema if exists eg_private cascade;
create schema eg_private;
revoke all on schema eg_private from public;
grant usage on schema eg_private
    to :DATABASE_MIGRATOR;

----------------
-- Now, we're going to add a user type column to distinguish
-- between teachers and students. There's no overlap, and no need
-- for a user to ever change its type
----------------
alter table eg_public.user
    drop column if exists user_type;
drop type if exists eg_public.user_type;

create type eg_public.user_type as enum('STUDENT', 'TEACHER');
alter table eg_public.user
    add column user_type eg_public.user_type not null;


----------------
-- Let's make the user_type column un-editable. We could achieve the
-- same thing with role permissions by not granting update of the column
-- to any roles, but when it's not expensive to do so, I like to enforce
-- things as close to the data as possible
--
-- It's a bit weird that the condition that warrants the error lives in
-- the trigger definition and not the function definition, but I have
-- a suspicion this is more performant. Blog post idea!
----------------
create function eg_private.tg__user__type_uneditable()
returns trigger as $$
begin
    raise 'eg_public.user.user_type cannot be changed';
    return new;
end;
$$ language plpgsql security definer;
drop trigger if exists _500_user_type_uneditable
    on eg_public.user;
create trigger _500_user_type_uneditable
    before update on eg_public.user
    for each row
    when (old.user_type is distinct from new.user_type)
    execute procedure eg_private.tg__user__type_uneditable();


----------------
-- Now, let's create a class table
----------------
drop table if exists eg_public.class;
create table eg_public.class (
    id uuid primary key default uuid_generate_v4(),
    name text not null check (length(name) > 2 and length(name) < 100),
    teacher_id uuid not null references eg_public.user(id)
);

----------------
-- There's no built-in way to check a column on the teacher being
-- referenced by the teacher_id table, so we'll have to do these checks
-- separately.
--
-- Normally, we'd worry about race conditions because the user_type
-- column could be updated in a concurrent session, and this trigger
-- would succeed. In this case, since we prevented the user column
-- from being updated, we know it is safe.
----------------
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


---------------
-- We need an index on eg_public.class.teacher_id to make the
-- teacher.classes connection performant.
---------------
create index class_teacher_id
    on eg_public.class(teacher_id);
