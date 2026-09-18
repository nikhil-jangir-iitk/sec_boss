-- Take `get_user_roles_for_hook` away from `authenticated`.
--
-- It is SECURITY DEFINER, it takes a user id as a parameter, and it returns that
-- user's role names:
--
--   CREATE FUNCTION public.get_user_roles_for_hook(check_user_id uuid)
--     RETURNS text[] LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
--     ... SELECT ARRAY_AGG(r.name ORDER BY ur.assigned_at)
--         FROM public.user_roles ur JOIN public.roles r ON r.id = ur.role_id
--         WHERE ur.user_id = check_user_id
--
-- `authenticated` can execute it, so any signed-in user can read any other
-- user's roles by passing their id to `/rest/v1/rpc/get_user_roles_for_hook`.
-- SECURITY DEFINER is what makes that work: `user_roles` has RLS, and its
-- policies give an ordinary user their own rows only ("Users can view their own
-- roles"), with everything else behind "Admins can view all roles". Reading the
-- table directly returns nothing for another user. The function returns the
-- answer anyway, because it runs as its owner.
--
-- This is a leftover grant rather than a design decision, and the two functions
-- next to it are the evidence. The token hook calls three helpers, all SECURITY
-- DEFINER, all taking the same `check_user_id uuid`:
--
--   get_user_roles_for_hook     authenticated, postgres, service_role, supabase_auth_admin
--   get_effective_permissions                  postgres, service_role, supabase_auth_admin
--   get_user_orgs_for_hook                     postgres, service_role, supabase_auth_admin
--
-- Same family, same shape, same caller, and only one of them is reachable by a
-- client. The grant comes from 20251023000014, which handed `anon` and
-- `authenticated` EXECUTE on this function explicitly. 20260908030000 later
-- swept `anon` off it and says in its own header that `authenticated` was left
-- alone deliberately, as a scoping decision for that migration rather than a
-- judgement about this function. 20260909130000 then did exactly this revoke
-- for `custom_access_token_hook` itself, the function these three serve.
--
-- Nothing calls it from a client. The only references outside the migrations are
-- two assertions in supabase/tests/boss_org_member_role_test.sql, which run as
-- the test role and are unaffected. The desktop client and every Edge Function
-- read roles through the JWT claims the hook already wrote, not by calling this.
--
-- Scope: this is the grant only. The function keeps its body, its definer mode
-- and its `search_path TO 'public'`. Whether the roles a user can see about
-- THEMSELVES should come from a narrower function is a separate question, and
-- the answer today is that they already have it in their token.

REVOKE ALL ON FUNCTION "public"."get_user_roles_for_hook"("check_user_id" "uuid") FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."get_user_roles_for_hook"("check_user_id" "uuid") FROM "anon";
REVOKE ALL ON FUNCTION "public"."get_user_roles_for_hook"("check_user_id" "uuid") FROM "authenticated";

-- Restated rather than assumed: these three are what the hook needs to keep
-- working, and a REVOKE that also caught them would stop every login.
GRANT EXECUTE ON FUNCTION "public"."get_user_roles_for_hook"("check_user_id" "uuid") TO "supabase_auth_admin";
GRANT EXECUTE ON FUNCTION "public"."get_user_roles_for_hook"("check_user_id" "uuid") TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."get_user_roles_for_hook"("check_user_id" "uuid") TO "postgres";
