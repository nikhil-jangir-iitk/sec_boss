-- expect: 13 fails. The admin check takes the row's user_id, so it is per row and answers for the target.
ALTER POLICY "Admins can remove roles" ON public.user_roles
  USING ((( SELECT is_user_admin(user_id) ) AND (NOT ((user_id = ( SELECT auth.uid() )) AND (role_id IN ( SELECT roles.id FROM roles WHERE (roles.name = 'admin'::text)))))));
