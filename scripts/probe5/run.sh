#!/usr/bin/env bash
# Scratch. Runs one pgTAP file through psql, optionally after a mutation, all
# inside one transaction that the test file's own ROLLBACK undoes.
#   run.sh <test.sql> [mutation.sql]
set -u
T=$1
M=${2:-}
out=$( { echo "begin;"; echo "create extension if not exists pgtap with schema extensions;"; if [ -n "$M" ]; then cat "$M"; fi; cat "$T"; } |
       psql "$DB_URL" -X -q -tA -v ON_ERROR_STOP=0 2>&1 )
label="$(basename "$T") + $( [ -n "$M" ] && basename "$M" || echo none )"
okn=$(grep -cE '^ok [0-9]+' <<<"$out")
bad=$(grep -E '^not ok [0-9]+' <<<"$out" | sed -E 's/^not ok ([0-9]+).*/\1/' | tr '\n' ' ')
plan=$(grep -E '^1\.\.[0-9]+' <<<"$out" | head -1)
err=$(grep -E 'ERROR' <<<"$out" | head -3 | tr '\n' ' ')
echo "RESULT [$label] plan=$plan ok=$okn failed=[${bad}]${err:+ errors: $err}"
if [ -n "$bad" ] || [ -n "$err" ]; then
  grep -E -A4 '^not ok' <<<"$out" | head -40 | sed 's/^/    /'
fi
