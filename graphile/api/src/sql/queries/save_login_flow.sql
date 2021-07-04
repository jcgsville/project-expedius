-- saveLoginFlow
select eg_hidden.save_login_flow(
    :'userId' :: uuid,
    :'serializedServerState' :: text
) as id;
