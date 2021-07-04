--  initiateSession
select 1 from eg_hidden.initiate_session(
    :'sessionId' :: text,
    :'userId' :: uuid
);
