#!/usr/bin/env python3
"""Scratch. Count splinter's auth_rls_initplan findings, with and without terminal_sessions."""
import csv, io, sys
raw = open(sys.argv[1], encoding="utf-8").read()
rows = [r for r in csv.DictReader(io.StringIO(raw[raw.index("name,title,level,"):])) if r["name"] == "auth_rls_initplan"]
tables = sorted({r["detail"].split("`")[1] for r in rows})
print("auth_rls_initplan findings:", len(rows))
print("without terminal_sessions:", sum("public.terminal_sessions" not in r["detail"] for r in rows))
print("tables:", len(tables))
