package buildinfo

import (
	"strings"
	"testing"
)

func TestStringDefaults(t *testing.T) {
	got := String()
	for _, want := range []string{"inference-observatory", "dev", "commit:", "built:"} {
		if !strings.Contains(got, want) {
			t.Errorf("String() = %q, missing %q", got, want)
		}
	}
}

func TestStringReflectsOverrides(t *testing.T) {
	savedV, savedC, savedD := Version, Commit, Date
	t.Cleanup(func() { Version, Commit, Date = savedV, savedC, savedD })

	Version = "v0.1.0"
	Commit = "deadbeef"
	Date = "2026-01-02T03:04:05Z"

	got := String()
	for _, want := range []string{"inference-observatory v0.1.0", "commit: deadbeef", "built: 2026-01-02T03:04:05Z"} {
		if !strings.Contains(got, want) {
			t.Errorf("String() = %q, missing %q", got, want)
		}
	}
}

func TestStringDeterministic(t *testing.T) {
	if String() != String() {
		t.Fatal("String() is not deterministic for fixed inputs")
	}
}
