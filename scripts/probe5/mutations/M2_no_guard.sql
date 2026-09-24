-- expect: 14 fails. Self-demotion guard dropped.
ALTER POLICY "Admins can remove roles" ON public.user_roles
  USING (( SELECT is_user_admin(( SELECT auth.uid() )) ));
