-- expect: 11 fails. Only the admin short-circuit, not authorize()'s role lookup.
ALTER POLICY "role.read can view plugin permission provenance" ON public.plugin_permissions
  USING (( SELECT is_user_admin(( SELECT auth.uid() )) ));
