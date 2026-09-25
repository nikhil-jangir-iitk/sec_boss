-- expect: 12 and 14 fail. Anyone may delete.
ALTER POLICY "Admins can remove roles" ON public.user_roles USING (true);
