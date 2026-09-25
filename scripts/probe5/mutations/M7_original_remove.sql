-- expect: 1 fails (un-hoisted again), 12-14 pass: the original per-row form admits the same rows.
ALTER POLICY "Admins can remove roles" ON public.user_roles
  USING ((public.is_user_admin(auth.uid()) AND NOT ((user_id = auth.uid()) AND (role_id IN (SELECT roles.id FROM public.roles WHERE (roles.name = 'admin'::text))))));
