-- expect: new test 1 fails; dev's test passes all 10 (the hole).
ALTER POLICY "terminal_sessions owner select" ON public.terminal_sessions
  USING (((( SELECT auth.uid() ) = user_id) AND (auth.role() = 'authenticated'::text)));
