-- retrieveLoginFlow
select eg_public.retrieve_login_flow(
    :'loginFlowId' :: uuid
) as state;
