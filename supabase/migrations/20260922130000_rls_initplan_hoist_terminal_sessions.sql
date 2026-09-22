-- Hoist the session call in the four terminal_sessions policies (follow-up to
-- 20260918140000).
--
-- 20260921120000_terminal_sessions created public.terminal_sessions after the
-- InitPlan hoist was written, with four owner policies that compare
-- `auth.uid()` to user_id directly. That is the shape 20260918140000 rewrote
-- across 80 policies: the call is evaluated once per candidate row instead of
-- once per statement, and Supabase's advisor reports it as auth_rls_initplan.
-- This applies the same rewrite to the four, so no policy in the schema is
-- left with an un-hoisted statement-constant call.
--
-- It is a separate migration dated after the terminal_sessions ones, rather
-- than more statements in 20260918140000, because that one runs before the
-- table exists.
--
-- Same method as 20260918140000: ALTER POLICY restating only USING and
-- WITH CHECK, so the command, the TO authenticated roles and PERMISSIVE are
-- carried over by PostgreSQL rather than retyped. auth.uid() takes no
-- arguments and is STABLE, so it passes the rule in that migration's header
-- and the rewrite cannot change which rows a policy admits.

ALTER POLICY "terminal_sessions owner select" ON public.terminal_sessions
  USING ((( SELECT auth.uid() ) = user_id));

ALTER POLICY "terminal_sessions owner insert" ON public.terminal_sessions
  WITH CHECK ((( SELECT auth.uid() ) = user_id));

ALTER POLICY "terminal_sessions owner update" ON public.terminal_sessions
  USING ((( SELECT auth.uid() ) = user_id))
  WITH CHECK ((( SELECT auth.uid() ) = user_id));

ALTER POLICY "terminal_sessions owner delete" ON public.terminal_sessions
  USING ((( SELECT auth.uid() ) = user_id));
