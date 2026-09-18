-- Measure what the hoist actually buys, in isolation.
--
-- This is a microbenchmark, not a measurement of the production tables. It
-- builds one table with 200k rows and two policies that differ only in whether
-- the call is hoisted, so the number attributable to the rewrite is the only
-- thing that varies. The helper is plpgsql STABLE SECURITY DEFINER, matching
-- public.is_user_admin, because a plpgsql function cannot be inlined and that
-- is what makes the per-row call expensive.

\timing off
set client_min_messages to warning;

create schema if not exists bench;

create table bench.rows_under_policy (id bigint primary key, owner uuid not null);

insert into bench.rows_under_policy
select g, '00000000-0000-0000-0000-000000000001'::uuid
from generate_series(1, 200000) g;

create table bench.calls (n bigint);
insert into bench.calls values (0);

-- Counts its own invocations, so the per-row versus per-statement difference is
-- observable as a number rather than inferred from a timing.
create or replace function bench.is_admin_like(u uuid)
returns boolean language plpgsql stable security definer as $$
begin
  update bench.calls set n = n + 1;
  return false;
end;
$$;

create role bench_reader;
grant usage on schema bench to bench_reader;
grant select on bench.rows_under_policy to bench_reader;
grant all on bench.calls to bench_reader;
grant execute on function bench.is_admin_like(uuid) to bench_reader;

alter table bench.rows_under_policy enable row level security;

-- The shape this migration replaces.
create policy per_row on bench.rows_under_policy for select to bench_reader
  using (bench.is_admin_like('00000000-0000-0000-0000-000000000001'::uuid)
         or owner = '00000000-0000-0000-0000-000000000001'::uuid);

\echo '--- per-row form ---'
set role bench_reader;
update bench.calls set n = 0;
explain (analyze, timing off, costs off, summary on)
  select count(*) from bench.rows_under_policy;
select n as helper_invocations_per_row_form from bench.calls;
reset role;

drop policy per_row on bench.rows_under_policy;

-- The shape this migration writes.
create policy hoisted on bench.rows_under_policy for select to bench_reader
  using ((select bench.is_admin_like('00000000-0000-0000-0000-000000000001'::uuid))
         or owner = '00000000-0000-0000-0000-000000000001'::uuid);

\echo '--- hoisted form ---'
set role bench_reader;
update bench.calls set n = 0;
explain (analyze, timing off, costs off, summary on)
  select count(*) from bench.rows_under_policy;
select n as helper_invocations_hoisted_form from bench.calls;
reset role;

drop schema bench cascade;
drop role bench_reader;
