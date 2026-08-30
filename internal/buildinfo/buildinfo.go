// Package buildinfo exposes version metadata injected at link time.
//
// Defaults make the binary usable when built without -ldflags overrides
// (for example `go build ./cmd/observatory` during local development).
// Production builds override these values through the Makefile via the
// linker -X flag, for example:
//
//	-ldflags "-X github.com/pillaiharish/inference-observatory/internal/buildinfo.Version=v0.1.0"
package buildinfo

import "fmt"

var (
	// Version is the semantic version of the build. Defaults to "dev".
	Version = "dev"
	// Commit is the source control revision the binary was built from.
	// "unknown" when not injected at build time.
	Commit = "unknown"
	// Date is the UTC build timestamp in RFC3339 form. "unknown" when
	// not injected at build time.
	Date = "unknown"
)

// String returns a deterministic, multi-line version banner suitable
// for the `observatory version` command.
func String() string {
	return fmt.Sprintf("inference-observatory %s\ncommit: %s\nbuilt: %s", Version, Commit, Date)
}
