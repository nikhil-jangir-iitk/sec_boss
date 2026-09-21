-- probe mutant M2: the privileged-read policy admits nothing
ALTER POLICY "Privileged users can read all users" ON public.users
  USING (false);
