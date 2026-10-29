#!/bin/sh
# Subcommands:
#   bench <bun bench args...>        run a benchmark; parquet lands in /results
#   report [parquet...]              print the stability report JSON (default: /results/*.parquet)
#   dump-cases <generator>           print the case set (ids, tools, messages, expected calls) as JSON
#   provenance                       print /harness/PROVENANCE.json
set -eu
cd /harness
case "${1:-}" in
  bench)
    shift
    mkdir -p /results
    # The harness writes bench-results/ relative to cwd; keep it on the mounted volume.
    rm -rf bench-results && ln -s /results bench-results
    exec bun src/cli/index.ts "$@"
    ;;
  report)
    shift
    # Default to every parquet the bench subcommand wrote; globs are expanded
    # here because the verifier invokes the container without a shell.
    if [ "$#" -eq 0 ]; then
      set -- /results/*.parquet
    fi
    exec bun src/benchmarks/toolcall-schema-fuzz/cli/report.ts "$@"
    ;;
  dump-cases)
    GEN="${2:-sentinel}"
    exec bun -e "
      import { toolCallSchemaFuzzCases } from './src/benchmarks/toolcall-schema-fuzz/cases';
      const cases = toolCallSchemaFuzzCases({ generator: '$GEN' });
      console.log(JSON.stringify(cases.map((c) => ({ id: c.id, scenario: c.scenario, strict: c.strict, constructs: c.constructs, control: c.control ?? null, tools: c.tools, messages: c.messages, calls: c.calls }))));
    "
    ;;
  provenance)
    exec cat /harness/PROVENANCE.json
    ;;
  --help|-h|"")
    sed -n '2,7p' "$0"
    ;;
  *)
    exec "$@"
    ;;
esac
