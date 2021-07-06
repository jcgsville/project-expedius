-- retrieveSession
select (eg_hidden.user_by_session_id(:'sessionId' :: text)).*;
