-- expect: 1 fails (un-hoisted again), 10-11 pass: the original per-row form admits the same rows.
ALTER POLICY "role.read can view plugin permission provenance" ON public.plugin_permissions
  USING (public.authorize('role.read'));
