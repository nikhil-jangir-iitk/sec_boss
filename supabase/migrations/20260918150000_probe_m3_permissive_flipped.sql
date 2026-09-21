-- probe mutant M3: same command, roles and expression, but RESTRICTIVE
DROP POLICY "Users can update own data" ON public.users;
CREATE POLICY "Users can update own data" ON public.users
  AS RESTRICTIVE FOR UPDATE
  USING ((( SELECT auth.uid() ) = id));
