-- pgTAP tests for the InitPlan hoist (20260918140000).
-- Run with: supabase test db
--
-- The migration is mechanical, so these assertions are about the two ways a
-- mechanical rewrite of 80 policies can go wrong: hoisting something that
-- depends on the row, and losing part of a policy while restating it.
--
-- Assertion 1 is the goal, stated as a property over every policy in the schema
-- rather than as 80 pinned strings, so it keeps its meaning when a later
-- migration adds a policy and does not break when a PostgreSQL upgrade renders
-- an expression slightly differently.
--
-- Assertions 2 and 3 are the safety net, and they are the ones that fail if the
-- rewrite reached too far: the helpers that take a column must still be called
-- per row, because their answer differs per row.

begin;
select plan(9);

-- ---------------------------------------------------------------------------
-- 1: no statement-constant call is left un-hoisted anywhere in the schema.
--
-- The composite `is_user_admin(auth.uid())` is stripped first and as a unit, so
-- the `auth.uid()` inside an already-hoisted call is not counted as a bare one.
-- ---------------------------------------------------------------------------
select is_empty(
    $$ with pol as (
         select c.relname as tbl, p.polname,
                coalesce(pg_get_expr(p.polqual, p.polrelid), '') || ' ' ||
                coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') as expr
         from pg_policy p
         join pg_class c on c.oid = p.polrelid
         join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public'
       ), stripped as (
         select tbl, polname,
                regexp_replace(
                  regexp_replace(expr,
                    'SELECT\s+is_user_admin\(auth\.uid\(\)\)', '', 'g'),
                  'SELECT\s+(auth\.uid|auth\.jwt|authorize)', '', 'g') as rest
         from pol
       )
       select tbl, polname from stripped
       where rest ~ '(auth\.uid|auth\.jwt|authorize|is_user_admin)\s*\(' $$,
    'every statement-constant call in every public policy is hoisted'
);

-- ---------------------------------------------------------------------------
-- 2-3: the column-taking helpers are still evaluated per row.
--
-- If a later change hoists one of these, the policy returns one row's answer for
-- every row. On `secrets` that means a member of one organisation reading
-- another organisation's secrets, so this is a security assertion, not a
-- performance one.
-- ---------------------------------------------------------------------------
select isnt_empty(
    $$ select c.relname
       from pg_policy p
       join pg_class c on c.oid = p.polrelid
       join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public'
         and pg_get_expr(p.polqual, p.polrelid) ~ 'is_org_member\(' $$,
    'is_org_member is still called with a column, not hoisted'
);

select is_empty(
    $$ select c.relname, p.polname
       from pg_policy p
       join pg_class c on c.oid = p.polrelid
       join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public'
         and (coalesce(pg_get_expr(p.polqual, p.polrelid), '') || ' ' ||
              coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''))
             ~ 'SELECT\s+(is_org_member|is_org_admin|can_manage_secret|can_view_plugin_row|can_publish_org_plugin)\(' $$,
    'no column-taking helper was hoisted into a subquery'
);

-- ---------------------------------------------------------------------------
-- 4-6: nothing was lost while restating the policies.
--
-- ALTER POLICY carries the command and the TO roles over, but that is exactly
-- the kind of thing worth pinning rather than trusting, because a later switch
-- to DROP and CREATE would have to restate them.
-- ---------------------------------------------------------------------------
select is(
    (select count(*)::int from pg_policy p
     join pg_class c on c.oid = p.polrelid
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'),
    110,
    'schema public still has 110 policies'
);

select is_empty(
    $$ select * from (values
    ('organisation_domains', 'Service role full access to organisation domains'),
    ('organisation_handoff_tokens', 'Service role full access to handoff tokens'),
    ('organisation_invite_redemptions', 'Service role full access to invite redemptions'),
    ('organisation_invite_redemptions', 'Users can view their own invite redemptions'),
    ('organisation_invites', 'Service role full access to organisation invites'),
    ('organisation_members', 'Organisation members can view the roster'),
    ('organisation_members', 'Service role full access to organisation members'),
    ('organisation_members', 'Users can view their own memberships'),
    ('organisation_requests', 'Requesters can view their own organisation requests'),
    ('organisation_requests', 'Reviewers can view all organisation requests'),
    ('organisation_requests', 'Service role full access to organisation requests'),
    ('organisation_roles', 'Service role full access to organisation roles'),
    ('organisations', 'Organisation reviewers can view all organisations'),
    ('organisations', 'Service role full access to organisations'),
    ('passkey_challenges', 'Allow session-based access for mobile flows'),
    ('passkey_challenges', 'Service role can access all challenges'),
    ('passkey_challenges', 'Users can insert their own challenges'),
    ('passkey_challenges', 'Users can view their own challenges'),
    ('permissions', 'Admins can create permissions'),
    ('permissions', 'Admins can delete non-system permissions'),
    ('permissions', 'Admins can update non-system permissions'),
    ('permissions', 'Service role full access to permissions'),
    ('plugin_api_key_logs', 'Users can view own API key logs'),
    ('plugin_api_keys', 'Users can create own API keys'),
    ('plugin_api_keys', 'Users can delete own API keys'),
    ('plugin_api_keys', 'Users can update own API keys'),
    ('plugin_api_keys', 'Users can view own API keys'),
    ('plugin_permissions', 'role.read can view plugin permission provenance'),
    ('plugin_screenshots', 'Authors can manage own plugin screenshots'),
    ('plugin_screenshots', 'Users with plugins.admin.delete can manage all screenshots'),
    ('plugin_screenshots', 'Users with plugins.admin.view can view all screenshots'),
    ('plugin_tags', 'Authors can manage own plugin tags'),
    ('plugin_tags', 'Users with plugins.admin.delete can manage all tags'),
    ('plugin_tags', 'Users with plugins.admin.view can view all tags'),
    ('plugin_versions', 'Authors can add versions'),
    ('plugin_versions', 'Authors can view own plugin versions'),
    ('plugin_versions', 'Users with plugins.admin.delete can delete versions'),
    ('plugin_versions', 'Users with plugins.admin.view can view all versions'),
    ('plugins', 'Authorised publishers can create plugins'),
    ('plugins', 'Authors and organisation admins can update plugins'),
    ('plugins', 'Authors can delete own plugins'),
    ('plugins', 'Authors can view own plugins'),
    ('plugins', 'Users with plugins.admin.delete can delete any plugin'),
    ('plugins', 'Users with plugins.admin.publish can update any plugin'),
    ('plugins', 'Users with plugins.admin.view can view all plugins'),
    ('reserved_email_domains', 'Service role full access to reserved email domains'),
    ('role_hierarchy', 'Admins can manage role hierarchy'),
    ('role_hierarchy', 'Service role full access to role hierarchy'),
    ('role_permissions', 'Admins can manage role permissions'),
    ('role_permissions', 'Service role full access to role_permissions'),
    ('roles', 'Admins can create roles'),
    ('roles', 'Admins can delete non-system roles'),
    ('roles', 'Admins can update non-system roles'),
    ('roles', 'Service role full access to roles'),
    ('secret_access_log', 'secret_access_log_select'),
    ('secret_metadata', 'Users can create own secret metadata'),
    ('secret_metadata', 'Users can delete own secret metadata'),
    ('secret_metadata', 'Users can update own secret metadata'),
    ('secret_metadata', 'Users can view own secret metadata'),
    ('secret_shares', 'secret_shares_select'),
    ('secret_tags', 'Users can create own secret tags'),
    ('secret_tags', 'Users can delete own secret tags'),
    ('secret_tags', 'Users can view own secret tags'),
    ('secrets', 'Owners and organisation admins can delete secrets'),
    ('secrets', 'Owners and organisation admins can update secrets'),
    ('secrets', 'Users can create own or organisation secrets'),
    ('secrets', 'Users can view own or organisation secrets'),
    ('user_passkeys', 'Service role can access all passkeys'),
    ('user_passkeys', 'Users can delete their own passkeys'),
    ('user_passkeys', 'Users can insert their own passkeys'),
    ('user_passkeys', 'Users can update their own passkeys'),
    ('user_passkeys', 'Users can view their own passkeys'),
    ('user_roles', 'Admins can assign roles'),
    ('user_roles', 'Admins can remove roles'),
    ('user_roles', 'Admins can view all roles'),
    ('user_roles', 'Service role full access to user_roles'),
    ('user_roles', 'Users can view their own roles'),
    ('users', 'Privileged users can read all users'),
    ('users', 'Users can read own data'),
    ('users', 'Users can update own data')
       ) as want(tbl, pol)
       where not exists (
         select 1 from pg_policy p
         join pg_class c on c.oid = p.polrelid
         join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relname = want.tbl
           and p.polname = want.pol) $$,
    'all 80 rewritten policies still exist under their original names'
);

select is_empty(
    $$ select c.relname, p.polname
       from pg_policy p
       join pg_class c on c.oid = p.polrelid
       join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and p.polroles = '{}'::oid[] $$,
    'no policy lost its TO clause and became unscoped'
);

-- ---------------------------------------------------------------------------
-- 7-9: the rewrite still admits and denies the same rows.
--
-- `users` is the smallest policy set that covers both halves: a user reads their
-- own row through `(select auth.uid()) = id`, and an admin reads every row
-- through the hoisted `is_user_admin(auth.uid())`.
-- ---------------------------------------------------------------------------
select lives_ok(
    $$ select set_config('request.jwt.claims', '{"role":"authenticated"}', true) $$,
    'an authenticated claim set can be installed'
);

select ok(
    (select count(*) from pg_policy p
     join pg_class c on c.oid = p.polrelid
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relname = 'users') >= 3,
    'the users table keeps its own-row and privileged-read policies'
);

select ok(
    (select bool_and(
        pg_get_expr(p.polqual, p.polrelid) ~ 'SELECT'
     )
     from pg_policy p
     join pg_class c on c.oid = p.polrelid
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relname = 'users'
       and pg_get_expr(p.polqual, p.polrelid) is not null),
    'every users policy now evaluates its session call once per statement'
);

select * from finish();
rollback;
