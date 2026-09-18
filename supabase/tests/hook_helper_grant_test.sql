-- pgTAP tests for the hook-helper revoke (20260919020000).
-- Run with: supabase test db
--
-- The point of these assertions is not that a grant was removed. It is that the
-- grant was the ONLY thing standing between a signed-in user and every other
-- user's roles, which is what makes the removal worth making and what a future
-- convenience regrant would undo.
--
-- Assertion 4 is the one to keep. It establishes, by reading the policies rather
-- than by assertion, that RLS on user_roles gives an ordinary user their own
-- rows only. That is the control the SECURITY DEFINER function was bypassing, so
-- if it ever stops being true this test is measuring the wrong thing and should
-- fail loudly rather than keep passing.

begin;
select plan(11);

-- ---------------------------------------------------------------------------
-- 1-3: the client roles cannot execute it any more.
-- ---------------------------------------------------------------------------
select ok(
    not pg_catalog.has_function_privilege('authenticated',
        'public.get_user_roles_for_hook(uuid)', 'EXECUTE'),
    'authenticated cannot execute get_user_roles_for_hook'
);

select ok(
    not pg_catalog.has_function_privilege('anon',
        'public.get_user_roles_for_hook(uuid)', 'EXECUTE'),
    'anon cannot execute get_user_roles_for_hook'
);

select is_empty(
    $$ select a.privilege_type
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       cross join lateral aclexplode(p.proacl) a
       where n.nspname = 'public'
         and p.proname = 'get_user_roles_for_hook'
         and a.grantee = 0 $$,
    'and PUBLIC holds no privilege on it either'
);

-- ---------------------------------------------------------------------------
-- 4: why it mattered. RLS on user_roles is per user, so the table itself never
-- gave a client another user's rows. The definer function did.
-- ---------------------------------------------------------------------------
select isnt_empty(
    $$ select p.polname
       from pg_policy p
       join pg_class c on c.oid = p.polrelid
       join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relname = 'user_roles'
         and pg_get_expr(p.polqual, p.polrelid) ~ 'auth\.uid\(\)' $$,
    'user_roles still restricts an ordinary reader to rows matching their own id'
);

select ok(
    (select c.relrowsecurity from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relname = 'user_roles'),
    'user_roles still has row level security enabled'
);

-- ---------------------------------------------------------------------------
-- 6-8: the login path is untouched. A revoke that caught supabase_auth_admin
-- would stop GoTrue minting any token at all, which is worse than the leak.
-- ---------------------------------------------------------------------------
select ok(
    pg_catalog.has_function_privilege('supabase_auth_admin',
        'public.get_user_roles_for_hook(uuid)', 'EXECUTE'),
    'supabase_auth_admin can still execute it, so the token hook still resolves roles'
);

select ok(
    pg_catalog.has_function_privilege('service_role',
        'public.get_user_roles_for_hook(uuid)', 'EXECUTE'),
    'service_role can still execute it'
);

select lives_ok(
    $$ select public.custom_access_token_hook(
         '{"user_id":"00000000-0000-0000-0000-000000000000","claims":{}}'::jsonb) $$,
    'the token hook still runs end to end'
);

-- ---------------------------------------------------------------------------
-- 9: the function itself is unchanged. This migration is a grant change, and a
-- later one that rewrote the body while "fixing" this would be a different PR.
-- ---------------------------------------------------------------------------
select ok(
    (select p.prosecdef from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'get_user_roles_for_hook'),
    'get_user_roles_for_hook is still SECURITY DEFINER'
);

-- ---------------------------------------------------------------------------
-- 10-11: its two siblings keep the grant set this one now matches. They are the
-- reason this was read as a leftover rather than a decision, so a change to them
-- should break this test and make someone re-read the argument.
-- ---------------------------------------------------------------------------
select ok(
    not pg_catalog.has_function_privilege('authenticated',
        'public.get_effective_permissions(uuid)', 'EXECUTE'),
    'get_effective_permissions is still closed to authenticated'
);

select ok(
    not pg_catalog.has_function_privilege('authenticated',
        'public.get_user_orgs_for_hook(uuid)', 'EXECUTE'),
    'get_user_orgs_for_hook is still closed to authenticated'
);

select * from finish();
rollback;
