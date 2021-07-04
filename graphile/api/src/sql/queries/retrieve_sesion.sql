-- retrieveSession
select eg_hidden.user_id_by_session_id(:'sessionId' :: text) as id;
