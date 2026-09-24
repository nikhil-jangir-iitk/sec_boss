-- expect: 10 fails. Provenance readable by anyone.
ALTER POLICY "role.read can view plugin permission provenance" ON public.plugin_permissions USING (true);
