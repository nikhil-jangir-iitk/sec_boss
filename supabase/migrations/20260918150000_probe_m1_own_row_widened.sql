-- probe mutant M1: the own-row policy admits every row
ALTER POLICY "Users can read own data" ON public.users
  USING (true);
