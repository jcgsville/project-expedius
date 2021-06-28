-- saveLoginFlow
select eg_public.save_login_flow(
    :'serializedServerState' :: text
) as id;
