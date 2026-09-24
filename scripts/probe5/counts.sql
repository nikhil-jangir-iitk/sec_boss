-- Scratch. Every call site of the nine functions the hoist classified, in every
-- public policy, per function, with and without terminal_sessions.
with pol as (
  select c.relname as tbl,
         coalesce(pg_get_expr(p.polqual, p.polrelid), '') || ' ' ||
         coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') as expr
  from pg_policy p
  join pg_class c on c.oid = p.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
), sites as (
  select tbl, m[1] as fn
  from pol, regexp_matches(expr,
    '\m(auth\.uid|auth\.jwt|auth\.role|authorize|is_user_admin|can_manage_secret|can_publish_org_plugin|can_view_plugin_row|is_org_admin|is_org_member)\s*\(', 'g') as m
)
select coalesce(fn, 'TOTAL') as fn, count(*) as sites,
       count(*) filter (where tbl <> 'terminal_sessions') as sites_without_terminal_sessions
from sites group by rollup(fn) order by fn nulls last;

select count(*) as public_policies,
       count(*) filter (where c.relname <> 'terminal_sessions') as without_terminal_sessions
from pg_policy p join pg_class c on c.oid = p.polrelid
join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public';

select p.oid::regprocedure as fn, p.provolatile as volatility
from pg_proc p where p.oid in ('auth.uid()'::regprocedure, 'auth.jwt()'::regprocedure, 'auth.role()'::regprocedure);
