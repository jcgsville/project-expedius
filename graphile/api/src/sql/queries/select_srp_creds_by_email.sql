-- selectSrpCredsByEmail
select * from eg_hidden.srp_creds_by_email(:'email' :: citext);
