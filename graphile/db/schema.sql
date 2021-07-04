--
-- PostgreSQL database dump
--

-- Dumped from database version 12.7
-- Dumped by pg_dump version 13.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: eg_hidden; Type: SCHEMA; Schema: -; Owner: eg_migrator
--

CREATE SCHEMA eg_hidden;


ALTER SCHEMA eg_hidden OWNER TO eg_migrator;

--
-- Name: eg_private; Type: SCHEMA; Schema: -; Owner: eg_migrator
--

CREATE SCHEMA eg_private;


ALTER SCHEMA eg_private OWNER TO eg_migrator;

--
-- Name: eg_public; Type: SCHEMA; Schema: -; Owner: eg_migrator
--

CREATE SCHEMA eg_public;


ALTER SCHEMA eg_public OWNER TO eg_migrator;

--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: eg_migrator
--

CREATE SCHEMA extensions;


ALTER SCHEMA extensions OWNER TO eg_migrator;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: srp_creds; Type: TYPE; Schema: eg_hidden; Owner: eg_migrator
--

CREATE TYPE eg_hidden.srp_creds AS (
	id uuid,
	salt text,
	verifier text
);


ALTER TYPE eg_hidden.srp_creds OWNER TO eg_migrator;

--
-- Name: sign_up_result; Type: TYPE; Schema: eg_public; Owner: eg_migrator
--

CREATE TYPE eg_public.sign_up_result AS ENUM (
    'USER_WITH_EMAIL_EXISTS',
    'SUCCESS'
);


ALTER TYPE eg_public.sign_up_result OWNER TO eg_migrator;

--
-- Name: user_type; Type: TYPE; Schema: eg_public; Owner: eg_migrator
--

CREATE TYPE eg_public.user_type AS ENUM (
    'STUDENT',
    'TEACHER'
);


ALTER TYPE eg_public.user_type OWNER TO eg_migrator;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: session; Type: TABLE; Schema: eg_private; Owner: eg_migrator
--

CREATE TABLE eg_private.session (
    id text NOT NULL,
    user_id uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL
);


ALTER TABLE eg_private.session OWNER TO eg_migrator;

--
-- Name: initiate_session(text, uuid); Type: FUNCTION; Schema: eg_hidden; Owner: eg_migrator
--

CREATE FUNCTION eg_hidden.initiate_session(session_id text, user_id uuid) RETURNS eg_private.session
    LANGUAGE sql STRICT SECURITY DEFINER
    SET search_path TO 'extensions'
    AS $$
    insert into eg_private.session (
        id,
        user_id,
        expires_at
    ) values (
        session_id,
        user_id,
        now() + interval '30 days'
    ) returning *;
$$;


ALTER FUNCTION eg_hidden.initiate_session(session_id text, user_id uuid) OWNER TO eg_migrator;

--
-- Name: login_flow; Type: TABLE; Schema: eg_private; Owner: eg_migrator
--

CREATE TABLE eg_private.login_flow (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    serialized_server_state text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    user_id uuid NOT NULL
);


ALTER TABLE eg_private.login_flow OWNER TO eg_migrator;

--
-- Name: retrieve_login_flow(uuid); Type: FUNCTION; Schema: eg_hidden; Owner: eg_migrator
--

CREATE FUNCTION eg_hidden.retrieve_login_flow(login_flow_id uuid) RETURNS eg_private.login_flow
    LANGUAGE sql STABLE STRICT SECURITY DEFINER
    SET search_path TO 'extensions'
    AS $$
    select *
    from eg_private.login_flow
    where id = login_flow_id
        and now() < expires_at;
$$;


ALTER FUNCTION eg_hidden.retrieve_login_flow(login_flow_id uuid) OWNER TO eg_migrator;

--
-- Name: save_login_flow(uuid, text); Type: FUNCTION; Schema: eg_hidden; Owner: eg_migrator
--

CREATE FUNCTION eg_hidden.save_login_flow(user_id uuid, serialized_server_state text) RETURNS uuid
    LANGUAGE sql STRICT SECURITY DEFINER
    SET search_path TO 'extensions'
    AS $$
    insert into eg_private.login_flow(
        serialized_server_state,
        expires_at,
        user_id
    ) values (
        serialized_server_state,
        now() + interval '1 minute',
        user_id
    ) returning id;
$$;


ALTER FUNCTION eg_hidden.save_login_flow(user_id uuid, serialized_server_state text) OWNER TO eg_migrator;

--
-- Name: srp_creds_by_email(extensions.citext); Type: FUNCTION; Schema: eg_hidden; Owner: eg_migrator
--

CREATE FUNCTION eg_hidden.srp_creds_by_email(user_email extensions.citext) RETURNS eg_hidden.srp_creds
    LANGUAGE sql STRICT SECURITY DEFINER
    SET search_path TO 'extensions'
    AS $$
    select
        u.id,
        uli.salt,
        us.verifier
    from eg_public.user u
    join eg_public.user_login_info uli on u.id = uli.user_id
    join eg_private.user_secrets us on u.id = us.user_id
    where u.email = user_email;
$$;


ALTER FUNCTION eg_hidden.srp_creds_by_email(user_email extensions.citext) OWNER TO eg_migrator;

--
-- Name: user_id_by_session_id(text); Type: FUNCTION; Schema: eg_hidden; Owner: eg_migrator
--

CREATE FUNCTION eg_hidden.user_id_by_session_id(session_id text) RETURNS uuid
    LANGUAGE sql STABLE STRICT SECURITY DEFINER
    SET search_path TO 'extensions'
    AS $$
    select
        u.id
    from eg_private.session s
    join eg_public.user u on u.id = s.user_id
    where s.id = session_id
        and s.expires_at > now();
$$;


ALTER FUNCTION eg_hidden.user_id_by_session_id(session_id text) OWNER TO eg_migrator;

--
-- Name: tg__class__teacher_correct_user_type(); Type: FUNCTION; Schema: eg_private; Owner: eg_migrator
--

CREATE FUNCTION eg_private.tg__class__teacher_correct_user_type() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION eg_private.tg__class__teacher_correct_user_type() OWNER TO eg_migrator;

--
-- Name: tg__login_flow__delete_expired(); Type: FUNCTION; Schema: eg_private; Owner: eg_migrator
--

CREATE FUNCTION eg_private.tg__login_flow__delete_expired() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'extensions'
    AS $$
begin
    delete from eg_private.login_flow
    where expires_at < now() - interval '30 seconds';

    return new;
end;
$$;


ALTER FUNCTION eg_private.tg__login_flow__delete_expired() OWNER TO eg_migrator;

--
-- Name: tg__user__type_uneditable(); Type: FUNCTION; Schema: eg_private; Owner: eg_migrator
--

CREATE FUNCTION eg_private.tg__user__type_uneditable() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
    raise 'eg_public.user.user_type cannot be changed';
    return new;
end;
$$;


ALTER FUNCTION eg_private.tg__user__type_uneditable() OWNER TO eg_migrator;

--
-- Name: sign_up(extensions.citext, eg_public.user_type, text, text); Type: FUNCTION; Schema: eg_public; Owner: eg_migrator
--

CREATE FUNCTION eg_public.sign_up(email extensions.citext, user_type eg_public.user_type, verifier text, salt text) RETURNS eg_public.sign_up_result
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    SET search_path TO 'extensions'
    AS $$
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
$$;


ALTER FUNCTION eg_public.sign_up(email extensions.citext, user_type eg_public.user_type, verifier text, salt text) OWNER TO eg_migrator;

--
-- Name: user_login_salt(extensions.citext); Type: FUNCTION; Schema: eg_public; Owner: eg_migrator
--

CREATE FUNCTION eg_public.user_login_salt(user_email extensions.citext) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    select salt
    from eg_public.user_login_info
    where email = user_email;
$$;


ALTER FUNCTION eg_public.user_login_salt(user_email extensions.citext) OWNER TO eg_migrator;

--
-- Name: user_secrets; Type: TABLE; Schema: eg_private; Owner: eg_migrator
--

CREATE TABLE eg_private.user_secrets (
    user_id uuid NOT NULL,
    verifier text NOT NULL
);


ALTER TABLE eg_private.user_secrets OWNER TO eg_migrator;

--
-- Name: class; Type: TABLE; Schema: eg_public; Owner: eg_migrator
--

CREATE TABLE eg_public.class (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    teacher_id uuid NOT NULL,
    CONSTRAINT class_name_check CHECK (((length(name) > 2) AND (length(name) < 100)))
);


ALTER TABLE eg_public.class OWNER TO eg_migrator;

--
-- Name: user; Type: TABLE; Schema: eg_public; Owner: eg_migrator
--

CREATE TABLE eg_public."user" (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    email extensions.citext NOT NULL,
    name text NOT NULL,
    user_type eg_public.user_type NOT NULL,
    CONSTRAINT user_email_check CHECK ((email OPERATOR(extensions.~) '^.+@.+\..+$'::extensions.citext)),
    CONSTRAINT user_name_check CHECK ((length(name) > 1))
);


ALTER TABLE eg_public."user" OWNER TO eg_migrator;

--
-- Name: user_login_info; Type: TABLE; Schema: eg_public; Owner: eg_migrator
--

CREATE TABLE eg_public.user_login_info (
    user_id uuid NOT NULL,
    email extensions.citext NOT NULL,
    salt text NOT NULL
);


ALTER TABLE eg_public.user_login_info OWNER TO eg_migrator;

--
-- Name: login_flow login_flow_pkey; Type: CONSTRAINT; Schema: eg_private; Owner: eg_migrator
--

ALTER TABLE ONLY eg_private.login_flow
    ADD CONSTRAINT login_flow_pkey PRIMARY KEY (id);


--
-- Name: session session_pkey; Type: CONSTRAINT; Schema: eg_private; Owner: eg_migrator
--

ALTER TABLE ONLY eg_private.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (id);


--
-- Name: user_secrets user_secrets_pkey; Type: CONSTRAINT; Schema: eg_private; Owner: eg_migrator
--

ALTER TABLE ONLY eg_private.user_secrets
    ADD CONSTRAINT user_secrets_pkey PRIMARY KEY (user_id);


--
-- Name: class class_pkey; Type: CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (id);


--
-- Name: user unique_email; Type: CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public."user"
    ADD CONSTRAINT unique_email UNIQUE (email);


--
-- Name: user unique_email_id; Type: CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public."user"
    ADD CONSTRAINT unique_email_id UNIQUE (email, id);


--
-- Name: user_login_info user_login_info_pkey; Type: CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public.user_login_info
    ADD CONSTRAINT user_login_info_pkey PRIMARY KEY (user_id);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: login_flow_user_id_idx; Type: INDEX; Schema: eg_private; Owner: eg_migrator
--

CREATE INDEX login_flow_user_id_idx ON eg_private.login_flow USING btree (user_id);


--
-- Name: session_user_id_idx; Type: INDEX; Schema: eg_private; Owner: eg_migrator
--

CREATE INDEX session_user_id_idx ON eg_private.session USING btree (user_id);


--
-- Name: class_teacher_id; Type: INDEX; Schema: eg_public; Owner: eg_migrator
--

CREATE INDEX class_teacher_id ON eg_public.class USING btree (teacher_id);


--
-- Name: user_login_info_email_idx; Type: INDEX; Schema: eg_public; Owner: eg_migrator
--

CREATE INDEX user_login_info_email_idx ON eg_public.user_login_info USING btree (email);


--
-- Name: login_flow _900_delete_expired; Type: TRIGGER; Schema: eg_private; Owner: eg_migrator
--

CREATE TRIGGER _900_delete_expired AFTER INSERT ON eg_private.login_flow FOR EACH STATEMENT EXECUTE FUNCTION eg_private.tg__login_flow__delete_expired();


--
-- Name: class _500_teacher_correct_user_type_insert; Type: TRIGGER; Schema: eg_public; Owner: eg_migrator
--

CREATE TRIGGER _500_teacher_correct_user_type_insert BEFORE INSERT ON eg_public.class FOR EACH ROW EXECUTE FUNCTION eg_private.tg__class__teacher_correct_user_type();


--
-- Name: user _500_user_type_uneditable; Type: TRIGGER; Schema: eg_public; Owner: eg_migrator
--

CREATE TRIGGER _500_user_type_uneditable BEFORE UPDATE ON eg_public."user" FOR EACH ROW WHEN ((old.user_type IS DISTINCT FROM new.user_type)) EXECUTE FUNCTION eg_private.tg__user__type_uneditable();


--
-- Name: class _501_teacher_correct_user_type_update; Type: TRIGGER; Schema: eg_public; Owner: eg_migrator
--

CREATE TRIGGER _501_teacher_correct_user_type_update BEFORE UPDATE ON eg_public.class FOR EACH ROW WHEN ((old.teacher_id IS DISTINCT FROM new.teacher_id)) EXECUTE FUNCTION eg_private.tg__class__teacher_correct_user_type();


--
-- Name: login_flow login_flow_user_id_fkey; Type: FK CONSTRAINT; Schema: eg_private; Owner: eg_migrator
--

ALTER TABLE ONLY eg_private.login_flow
    ADD CONSTRAINT login_flow_user_id_fkey FOREIGN KEY (user_id) REFERENCES eg_public."user"(id) ON DELETE CASCADE;


--
-- Name: session session_user_id_fkey; Type: FK CONSTRAINT; Schema: eg_private; Owner: eg_migrator
--

ALTER TABLE ONLY eg_private.session
    ADD CONSTRAINT session_user_id_fkey FOREIGN KEY (user_id) REFERENCES eg_public."user"(id) ON DELETE CASCADE;


--
-- Name: user_secrets user_secrets_user_id_fkey; Type: FK CONSTRAINT; Schema: eg_private; Owner: eg_migrator
--

ALTER TABLE ONLY eg_private.user_secrets
    ADD CONSTRAINT user_secrets_user_id_fkey FOREIGN KEY (user_id) REFERENCES eg_public."user"(id) ON DELETE CASCADE;


--
-- Name: class class_teacher_id_fkey; Type: FK CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public.class
    ADD CONSTRAINT class_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES eg_public."user"(id);


--
-- Name: user user_id_login_info_fkey; Type: FK CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public."user"
    ADD CONSTRAINT user_id_login_info_fkey FOREIGN KEY (id) REFERENCES eg_public.user_login_info(user_id) ON DELETE RESTRICT;


--
-- Name: user user_id_secrets_fkey; Type: FK CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public."user"
    ADD CONSTRAINT user_id_secrets_fkey FOREIGN KEY (id) REFERENCES eg_private.user_secrets(user_id) ON DELETE RESTRICT;


--
-- Name: user_login_info user_login_info_user_id_email_fkey; Type: FK CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public.user_login_info
    ADD CONSTRAINT user_login_info_user_id_email_fkey FOREIGN KEY (user_id, email) REFERENCES eg_public."user"(id, email) ON DELETE CASCADE;


--
-- Name: user_login_info user_login_info_user_id_fkey; Type: FK CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public.user_login_info
    ADD CONSTRAINT user_login_info_user_id_fkey FOREIGN KEY (user_id) REFERENCES eg_public."user"(id) ON DELETE CASCADE;


--
-- Name: SCHEMA eg_public; Type: ACL; Schema: -; Owner: eg_migrator
--

GRANT USAGE ON SCHEMA eg_public TO eg_student;
GRANT USAGE ON SCHEMA eg_public TO eg_teacher;


--
-- Name: SCHEMA extensions; Type: ACL; Schema: -; Owner: eg_migrator
--

GRANT USAGE ON SCHEMA extensions TO eg_api;
GRANT USAGE ON SCHEMA extensions TO eg_anon;
GRANT USAGE ON SCHEMA extensions TO eg_student;
GRANT USAGE ON SCHEMA extensions TO eg_teacher;


--
-- Name: FUNCTION sign_up(email extensions.citext, user_type eg_public.user_type, verifier text, salt text); Type: ACL; Schema: eg_public; Owner: eg_migrator
--

GRANT ALL ON FUNCTION eg_public.sign_up(email extensions.citext, user_type eg_public.user_type, verifier text, salt text) TO eg_student;
GRANT ALL ON FUNCTION eg_public.sign_up(email extensions.citext, user_type eg_public.user_type, verifier text, salt text) TO eg_teacher;


--
-- Name: FUNCTION user_login_salt(user_email extensions.citext); Type: ACL; Schema: eg_public; Owner: eg_migrator
--

GRANT ALL ON FUNCTION eg_public.user_login_salt(user_email extensions.citext) TO eg_student;
GRANT ALL ON FUNCTION eg_public.user_login_salt(user_email extensions.citext) TO eg_teacher;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: eg_public; Owner: eg_migrator
--

ALTER DEFAULT PRIVILEGES FOR ROLE eg_migrator IN SCHEMA eg_public REVOKE ALL ON FUNCTIONS  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE eg_migrator IN SCHEMA eg_public REVOKE ALL ON FUNCTIONS  FROM eg_migrator;
ALTER DEFAULT PRIVILEGES FOR ROLE eg_migrator IN SCHEMA eg_public GRANT ALL ON FUNCTIONS  TO eg_student;
ALTER DEFAULT PRIVILEGES FOR ROLE eg_migrator IN SCHEMA eg_public GRANT ALL ON FUNCTIONS  TO eg_teacher;


--
-- PostgreSQL database dump complete
--

