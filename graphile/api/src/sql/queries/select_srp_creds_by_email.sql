-- selectSrpCredsByEmail
select * from eg_public.srp_creds_by_email(:'email' :: citext);
