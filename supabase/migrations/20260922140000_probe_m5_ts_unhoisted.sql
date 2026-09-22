ALTER POLICY "terminal_sessions owner select" ON public.terminal_sessions USING ((auth.uid() = user_id));
