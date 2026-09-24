-- Probe-only. Checks two claims before they go into #994's header and reply.
begin;
select plan(6);

-- A NULL proacl: reading entries finds no PUBLIC row, has_function_privilege says PUBLIC can execute.
select ok(
    (select p.proacl is null from pg_catalog.pg_proc p where p.oid = 'pg_catalog.lower(text)'::regprocedure),
    'probe: lower(text) has a NULL proacl'
);
select is(
    (select pg_catalog.count(*)::int from pg_catalog.pg_proc p
     cross join lateral pg_catalog.aclexplode(p.proacl) a
     where p.oid = 'pg_catalog.lower(text)'::regprocedure and a.grantee = 0),
    0,
    'probe: reading proacl finds no PUBLIC entry on it'
);
select ok(
    pg_catalog.has_function_privilege('public', 'pg_catalog.lower(text)', 'EXECUTE'),
    'probe: has_function_privilege says PUBLIC can execute it'
);

-- DROP FUNCTION + CREATE hands the helper back to authenticated.
select ok(
    not pg_catalog.has_function_privilege('authenticated', 'public.get_user_roles_for_hook(uuid)', 'EXECUTE'),
    'probe: after the migration authenticated cannot execute it'
);
drop function public.get_user_roles_for_hook(uuid);
create function public.get_user_roles_for_hook(check_user_id uuid)
    returns text[] language sql security definer set search_path = ''
    as $$ select array[]::text[] $$;
select ok(
    pg_catalog.has_function_privilege('authenticated', 'public.get_user_roles_for_hook(uuid)', 'EXECUTE'),
    'probe: after DROP + CREATE authenticated can execute it again'
);
select ok(
    not pg_catalog.has_function_privilege('anon', 'public.get_user_roles_for_hook(uuid)', 'EXECUTE'),
    'probe: and anon cannot, because the event trigger strips it'
);

select * from finish();
rollback;
