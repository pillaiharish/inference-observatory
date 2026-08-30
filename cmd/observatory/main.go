// Package main implements the observatory CLI entrypoint.
//
// Prompt 1 only ships the `version` command plus basic help. Future
// commands (status, diagnose, compare, trace ...) will be added in
// later PRs and must slot into the dispatch table below without
// rewriting this file's structure.
package main

import (
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/pillaiharish/inference-observatory/internal/buildinfo"
)

const usage = `observatory - LLM inference observability and diagnosis

Usage:
  observatory <command> [flags]

Available commands:
  version        Print version and build information
  help           Show this help message

Future commands (not yet implemented):
  status         Summarize the last known observation state
  diagnose       Run deterministic bottleneck diagnosis
  compare        Compare two runs
  trace summary  Summarize a profiling trace
  trace diff     Diff two profiling traces

Flags:
  -h, --help     Show help
  -v, --version  Print version and exit

Exit codes:
  0  success
  1  runtime error
  2  usage error
`

func main() {
	if err := run(os.Stdout, os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(stdout io.Writer, args []string) error {
	if len(args) == 0 {
		fmt.Fprint(stdout, usage)
		return nil
	}

	switch args[0] {
	case "-h", "--help", "help":
		fmt.Fprint(stdout, usage)
		return nil
	case "-v", "--version":
		fmt.Fprintln(stdout, buildinfo.String())
		return nil
	case "version":
		if len(args) > 1 && (args[1] == "-h" || args[1] == "--help") {
			fmt.Fprint(stdout, usage)
			return nil
		}
		fmt.Fprintln(stdout, buildinfo.String())
		return nil
	default:
		return usageError(args[0])
	}
}

func usageError(cmd string) error {
	return fmt.Errorf("unknown command %q\n\n%s", strings.Trim(cmd, ""), strings.TrimSpace(usage))
}
