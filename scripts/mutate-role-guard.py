#!/usr/bin/env python3
"""Mutation checks for the role-reader guard, against one live database.

Each mutant is a deliberately broken copy of the migration. It is applied with
psql, the pgTAP file is run, and the failing assertion numbers are recorded.
A mutant that no assertion catches is a hole in the test, and fails the step.
The original migration is re-applied between mutants and at the end.
"""

import os
import re
import subprocess
import sys

DB = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
MIG = "supabase/migrations/20260919030000_guard_role_reader_functions.sql"
TEST = "supabase/tests/role_reader_guard_test.sql"

orig = open(MIG, encoding="utf-8").read()
# Re-applicable: the helper is created with CREATE, which cannot run twice.
base = orig.replace('CREATE FUNCTION "public"."can_read_user_roles"',
                    'CREATE OR REPLACE FUNCTION "public"."can_read_user_roles"')
assert base != orig


def cut(text, old, new):
    assert text.count(old) == 1, "anchor not unique: " + old[:60]
    return text.replace(old, new)


GUARD_WN = """    IF NOT public.can_read_user_roles(target_user_id) THEN
        RETURN '[]'::jsonb;
    END IF;
"""
GUARD_GR = """    IF NOT public.can_read_user_roles(check_user_id) THEN
        RETURN;
    END IF;
"""
GUARD_HR = """    IF NOT public.can_read_user_roles(check_user_id) THEN
        RETURN false;
    END IF;
"""

MUTANTS = [
    ("admins-only rule (authorize -> is_user_admin)",
     lambda s: cut(s, "OR public.authorize('role.read')",
                   "OR public.is_user_admin((SELECT auth.uid()))")),
    ("no COALESCE, so NULL fails open",
     lambda s: cut(cut(s, "    SELECT COALESCE(\n", "    SELECT (\n"),
                   "        OR public.authorize('role.read'),\n        false\n    );",
                   "        OR public.authorize('role.read')\n    );")),
    ("service-role clause dropped",
     lambda s: cut(s, "        OR (SELECT auth.jwt() ->> 'role') = 'service_role'\n", "")),
    ("guard removed from get_user_roles_with_names", lambda s: cut(s, GUARD_WN, "")),
    ("guard removed from get_user_roles", lambda s: cut(s, GUARD_GR, "")),
    ("guard removed from user_has_role", lambda s: cut(s, GUARD_HR, "")),
]


def psql_file(sql):
    p = subprocess.run(["psql", DB, "-v", "ON_ERROR_STOP=1", "-q", "-f", "-"],
                       input=sql, text=True, capture_output=True)
    if p.returncode:
        sys.exit("apply failed:\n" + p.stderr)


ENV = dict(os.environ, PGOPTIONS="-c search_path=public,extensions")


def run_test():
    p = subprocess.run(["psql", DB, "-q", "-t", "-A", "-f", TEST],
                       text=True, capture_output=True, env=ENV)
    out = p.stdout + p.stderr
    failed = sorted(int(n) for n in re.findall(r"^not ok (\d+)", out, re.M))
    passed = len(re.findall(r"^ok \d+", out, re.M))
    return passed, failed


# supabase test db installs pgTAP on the fly; a bare psql run has to do it.
psql_file("create extension if not exists pgtap with schema extensions;")
psql_file(base)
p, f = run_test()
print("baseline: %d pass, failing %s" % (p, f or "none"))
# A harness that runs nothing reports no failures too, so require every
# assertion to have actually passed before any mutant is allowed to count.
if f or p != 20:
    sys.exit("baseline is not a real green run (%d pass): the harness is broken" % p)

survivors = []
for name, mutate in MUTANTS:
    psql_file(mutate(base))
    p, f = run_test()
    print("%-50s -> caught by %s" % (name, f if f else "NOTHING"))
    if not f:
        survivors.append(name)
    psql_file(base)

p, f = run_test()
print("restored: %d pass, failing %s" % (p, f or "none"))
if survivors or f or p != 20:
    sys.exit("surviving mutants: %s" % survivors)
print("every mutant was caught")
