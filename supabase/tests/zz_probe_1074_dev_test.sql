-- Probe-only, on dev WITHOUT #1074: what anon holds on the three today.
begin;
select plan(1);
select is(
    (select pg_catalog.count(*)::int
     from (values ('public.get_user_roles(uuid)'),
                  ('public.get_user_roles_with_names(uuid)'),
                  ('public.user_has_role(uuid, text)')) as f(sig)
     where pg_catalog.has_function_privilege('anon', f.sig, 'EXECUTE')),
    3,
    'probe: on dev, anon can execute all three'
);
select * from finish();
rollback;
