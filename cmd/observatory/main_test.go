package main

import (
	"bytes"
	"errors"
	"strings"
	"testing"
)

func TestRunVersion(t *testing.T) {
	var out bytes.Buffer
	if err := run(&out, []string{"version"}); err != nil {
		t.Fatalf("version: %v", err)
	}
	if !strings.Contains(out.String(), "inference-observatory") {
		t.Errorf("version output missing banner: %q", out.String())
	}
}

func TestRunNoArgsPrintsUsage(t *testing.T) {
	var out bytes.Buffer
	if err := run(&out, nil); err != nil {
		t.Fatalf("no args: %v", err)
	}
	if !strings.Contains(out.String(), "Usage:") {
		t.Errorf("no args should print usage, got: %q", out.String())
	}
}

func TestRunHelp(t *testing.T) {
	for _, arg := range []string{"help", "-h", "--help"} {
		var out bytes.Buffer
		if err := run(&out, []string{arg}); err != nil {
			t.Errorf("help %q: %v", arg, err)
		}
		if !strings.Contains(out.String(), "Available commands:") {
			t.Errorf("help %q missing commands section: %q", arg, out.String())
		}
	}
}

func TestRunUnknownCommandIsUsageError(t *testing.T) {
	err := run(&bytes.Buffer{}, []string{"frobnicate"})
	if err == nil {
		t.Fatal("unknown command should error")
	}
	if !errors.Is(err, errUsage) {
		t.Errorf("unknown command should be errUsage (exit 2), got %T: %v", err, err)
	}
}

func TestVersionFlag(t *testing.T) {
	for _, arg := range []string{"-v", "--version"} {
		var out bytes.Buffer
		if err := run(&out, []string{arg}); err != nil {
			t.Errorf("%q: %v", arg, err)
		}
		if !strings.Contains(out.String(), "inference-observatory") {
			t.Errorf("%q missing banner: %q", arg, out.String())
		}
	}
}

// TestRunExitClassification verifies the documented exit-code contract by
// calling run() and checking error classification: success cases return
// nil (exit 0), usage errors are errUsage (exit 2), and other runtime
// errors would exit 1. The real main()/os.Exit mapping is exercised
// separately at the process level (see ./bin/observatory frobnicate).
func TestRunExitClassification(t *testing.T) {
	cases := []struct {
		name    string
		args    []string
		wantErr bool // a non-nil error means main would exit non-zero
		usage   bool // whether that error is a usage error (exit 2)
	}{
		{"version", []string{"version"}, false, false},
		{"help", []string{"--help"}, false, false},
		{"unknown", []string{"frobnicate"}, true, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := run(&bytes.Buffer{}, tc.args)
			switch {
			case !tc.wantErr && err != nil:
				t.Fatalf("expected success, got error: %v", err)
			case tc.wantErr && err == nil:
				t.Fatalf("expected error, got nil")
			case tc.wantErr && tc.usage && !errors.Is(err, errUsage):
				t.Fatalf("expected errUsage, got %T: %v", err, err)
			}
		})
	}
}
