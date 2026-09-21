-- probe mutant M4: same roles, permissiveness and expression, but FOR ALL
DROP POLICY "Users can update own data" ON public.users;
CREATE POLICY "Users can update own data" ON public.users
  FOR ALL
  USING ((( SELECT auth.uid() ) = id));
