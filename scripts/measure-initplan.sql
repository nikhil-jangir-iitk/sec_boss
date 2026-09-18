-- Measure what the hoist actually buys, in isolation.
--
-- This is a microbenchmark, not a measurement of the production tables. It
-- builds one table with 200k rows and two policies that differ only in whether
-- the call is hoisted, so the rewrite is the only thing that varies. The helper
-- is plpgsql STABLE SECURITY DEFINER, matching public.is_user_admin, because a
-- plpgsql function cannot be inlined and that is what makes the per-row call
-- expensive. It counts its own invocations, so the difference shows up as a
-- number rather than as a timing.
--
-- It runs as `authenticated`, which already exists here, rather than creating a
-- role: the local `postgres` is not a superuser.

set client_min_messages to warning;

drop schema if exists bench cascade;
create schema bench;

create table bench.rows_under_policy (id bigint primary key, owner uuid not null);
insert into bench.rows_under_policy
select g, '00000000-0000-0000-0000-000000000001'::uuid
from generate_series(1, 200000) g;

create table bench.calls (n bigint);
insert into bench.calls values (0);

create or replace function bench.is_admin_like(u uuid)
returns boolean language plpgsql stable security definer as $$
begin
  update bench.calls set n = n + 1;
  return false;
end;
$$;

grant usage on schema bench to authenticated;
grant select on bench.rows_under_policy to authenticated;
grant all on bench.calls to authenticated;
grant execute on function bench.is_admin_like(uuid) to authenticated;

alter table bench.rows_under_policy enable row level security;

-- The shape this migration replaces.
create policy per_row on bench.rows_under_policy for select to authenticated
  using (bench.is_admin_like('00000000-0000-0000-0000-000000000001'::uuid)
         or owner = '00000000-0000-0000-0000-000000000001'::uuid);

\echo '=== per-row form ==='
update bench.calls set n = 0;
set role authenticated;
explain (analyze, timing off, costs off)
  select count(*) from bench.rows_under_policy;
reset role;
select n as helper_calls_per_row_form from bench.calls;

drop policy per_row on bench.rows_under_policy;

-- The shape this migration writes.
create policy hoisted on bench.rows_under_policy for select to authenticated
  using ((select bench.is_admin_like('00000000-0000-0000-0000-000000000001'::uuid))
         or owner = '00000000-0000-0000-0000-000000000001'::uuid);

\echo '=== hoisted form ==='
update bench.calls set n = 0;
set role authenticated;
explain (analyze, timing off, costs off)
  select count(*) from bench.rows_under_policy;
reset role;
select n as helper_calls_hoisted_form from bench.calls;

drop schema bench cascade;
