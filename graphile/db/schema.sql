--
-- PostgreSQL database dump
--

-- Dumped from database version 12.6
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
-- Name: user_type; Type: TYPE; Schema: eg_public; Owner: eg_migrator
--

CREATE TYPE eg_public.user_type AS ENUM (
    'STUDENT',
    'TEACHER'
);


ALTER TYPE eg_public.user_type OWNER TO eg_migrator;

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

SET default_tablespace = '';

SET default_table_access_method = heap;

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
-- Name: class class_pkey; Type: CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (id);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: class_teacher_id; Type: INDEX; Schema: eg_public; Owner: eg_migrator
--

CREATE INDEX class_teacher_id ON eg_public.class USING btree (teacher_id);


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
-- Name: class class_teacher_id_fkey; Type: FK CONSTRAINT; Schema: eg_public; Owner: eg_migrator
--

ALTER TABLE ONLY eg_public.class
    ADD CONSTRAINT class_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES eg_public."user"(id);


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
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: eg_public; Owner: eg_migrator
--

ALTER DEFAULT PRIVILEGES FOR ROLE eg_migrator IN SCHEMA eg_public REVOKE ALL ON FUNCTIONS  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE eg_migrator IN SCHEMA eg_public REVOKE ALL ON FUNCTIONS  FROM eg_migrator;
ALTER DEFAULT PRIVILEGES FOR ROLE eg_migrator IN SCHEMA eg_public GRANT ALL ON FUNCTIONS  TO eg_student;
ALTER DEFAULT PRIVILEGES FOR ROLE eg_migrator IN SCHEMA eg_public GRANT ALL ON FUNCTIONS  TO eg_teacher;


--
-- PostgreSQL database dump complete
--

