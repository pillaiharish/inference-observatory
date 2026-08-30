package main

import (
	"bytes"
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

func TestRunUnknownCommandErrors(t *testing.T) {
	if err := run(&bytes.Buffer{}, []string{"frobnicate"}); err == nil {
		t.Fatal("unknown command should error")
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
