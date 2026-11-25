// Command neoagent-release is the release tooling CI runs: staging runtime
// archives, digesting and signing manifests, the generated setup contract and
// the release notes download section. Run it from the repository root:
//
//	go run ./cmd/neoagent-release <command> [flags]
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/release"
	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	nlrelease "github.com/NeoLabs-Systems/neolabs-go/cli/release"
)

const dartContract = "flutter_app/lib/src/setup_contract.g.dart"

const usage = `usage: neoagent-release <command> [flags]

  version                                   print the release version
  set-version VERSION                       write the release version and package.json's
  setup-contract [--check]                  write (or check) ` + dartContract + `
  signing-public-key                        print the embedded runtime signing key
  web-build-id                              print the web build id
  stage-qemu --output DIR                   stage the host QEMU as a portable runtime
  stage-runtime --output DIR --binary FILE --web DIR [--guest FILE]... [--landing DIR]
                [--computer-runtime DIR] [--license FILE] [--platform P] [--architecture A]
  runtime-archive --input DIR --output FILE zip a staged runtime
  runtime-metadata --asset FILE --output FILE --platform P --architecture A
  runtime-manifest --input DIR --output FILE --version V      (NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY)
  verify-manifest --manifest FILE --signature FILE           (NEOAGENT_RUNTIME_SIGNING_PUBLIC_KEY optional)
  release-manifest --input DIR --output FILE --version V      (NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY)
  release-download --tag TAG [--repo OWNER/NAME] [--dry-run]
`

type multi []string

func (m *multi) String() string     { return strings.Join(*m, ",") }
func (m *multi) Set(v string) error { *m = append(*m, v); return nil }

func hostPlatform() string {
	switch runtime.GOOS {
	case "darwin":
		return "macos"
	default:
		return runtime.GOOS
	}
}

func hostArchitecture() string {
	if runtime.GOARCH == "amd64" {
		return "x64"
	}
	return runtime.GOARCH
}

func required(fs *flag.FlagSet, names ...string) error {
	for _, n := range names {
		if strings.TrimSpace(fs.Lookup(n).Value.String()) == "" {
			return fmt.Errorf("--%s is required.", n)
		}
	}
	return nil
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	if err := run(ctx, os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "neoagent-release:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string) error {
	if len(args) == 0 {
		fmt.Fprint(os.Stderr, usage)
		return errors.New("a command is required")
	}
	fs := flag.NewFlagSet(args[0], flag.ContinueOnError)
	output := fs.String("output", "", "")
	input := fs.String("input", "", "")
	version := fs.String("version", "", "")
	platform := fs.String("platform", hostPlatform(), "")
	architecture := fs.String("architecture", hostArchitecture(), "")
	check := fs.Bool("check", false, "")
	dryRun := fs.Bool("dry-run", false, "")
	binary := fs.String("binary", "", "")
	web := fs.String("web", "", "")
	landing := fs.String("landing", "", "")
	computerRuntime := fs.String("computer-runtime", "", "")
	license := fs.String("license", "", "")
	asset := fs.String("asset", "", "")
	manifest := fs.String("manifest", "", "")
	signature := fs.String("signature", "", "")
	tag := fs.String("tag", "", "")
	repo := fs.String("repo", "", "")
	var guests multi
	fs.Var(&guests, "guest", "")
	if err := fs.Parse(args[1:]); err != nil {
		return err
	}
	privateKey := os.Getenv("NEOAGENT_RUNTIME_SIGNING_PRIVATE_KEY")

	switch args[0] {
	case "version":
		raw, err := os.ReadFile(release.VersionFile)
		if err != nil {
			return err
		}
		fmt.Println(strings.TrimSpace(string(raw)))
	case "set-version":
		if fs.NArg() != 1 {
			return errors.New("usage: neoagent-release set-version VERSION")
		}
		return release.SetVersion(".", fs.Arg(0))
	case "setup-contract":
		want := setupcontract.C.Dart(setupcontract.PublicKey())
		if *check {
			got, _ := os.ReadFile(dartContract)
			if string(got) != want {
				return errors.New("Generated Flutter setup contract is stale. Run go run ./cmd/neoagent-release setup-contract.")
			}
			return nil
		}
		return os.WriteFile(dartContract, []byte(want), 0o644)
	case "signing-public-key":
		fmt.Println(setupcontract.PublicKey())
	case "web-build-id":
		fmt.Print(release.WebBuildID(os.Getenv, time.Now()))
	case "stage-qemu":
		if err := required(fs, "output"); err != nil {
			return err
		}
		return release.StageQemu(ctx, *output)
	case "stage-runtime":
		if err := required(fs, "output", "binary", "web"); err != nil {
			return err
		}
		return release.StageRuntime(release.StageOptions{
			Output: *output, Binary: *binary, Guests: guests, WebDir: *web, LandingDir: *landing,
			ComputerRuntime: *computerRuntime, Platform: *platform, Architecture: *architecture, License: *license,
		})
	case "runtime-archive":
		if err := required(fs, "input", "output"); err != nil {
			return err
		}
		return nlrelease.CreateZip(*input, *output)
	case "runtime-metadata":
		if err := required(fs, "asset", "output", "platform", "architecture"); err != nil {
			return err
		}
		return release.WriteRuntimeMetadata(*asset, *output, *platform, *architecture)
	case "runtime-manifest":
		if err := required(fs, "input", "output", "version"); err != nil {
			return err
		}
		return release.WriteRuntimeManifest(*input, *output, *version, privateKey)
	case "verify-manifest":
		if err := required(fs, "manifest", "signature"); err != nil {
			return err
		}
		return release.VerifyManifest(*manifest, *signature, os.Getenv("NEOAGENT_RUNTIME_SIGNING_PUBLIC_KEY"))
	case "release-manifest":
		if err := required(fs, "input", "output", "version"); err != nil {
			return err
		}
		return release.WriteReleaseManifest(*input, *output, *version, privateKey)
	case "release-download":
		if err := required(fs, "tag"); err != nil {
			return err
		}
		repository := firstNonEmpty(*repo, os.Getenv("GITHUB_REPOSITORY"), release.Repository)
		changed, body, err := release.UpdateDownloadNotes(ctx, *tag, repository, *dryRun)
		if err != nil {
			return err
		}
		if *dryRun {
			fmt.Print(body)
		} else if !changed {
			fmt.Println("Release notes already current.")
		}
	default:
		fmt.Fprint(os.Stderr, usage)
		return fmt.Errorf("unknown command %q", args[0])
	}
	return nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}
