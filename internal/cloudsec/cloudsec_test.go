package cloudsec

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/netip"
	"os"
	"testing"
	"time"
)

// testdata/vectors.json is what Node's cloud-security helper answered for each
// URL and for each DNS outcome (regenerate with gen/vectors.js).
type vectors struct {
	Syntactic []struct {
		URL     string `json:"url"`
		Allowed bool   `json:"allowed"`
		Reason  string `json:"reason"`
	} `json:"syntactic"`
	DNS []struct {
		URL       string   `json:"url"`
		Addresses []string `json:"addresses"`
		Error     *string  `json:"error"`
		Allowed   bool     `json:"allowed"`
		Reason    string   `json:"reason"`
	} `json:"dns"`
}

func loadVectors(t *testing.T) vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestCheckMatchesNode(t *testing.T) {
	v := loadVectors(t)
	if len(v.Syntactic) < 70 {
		t.Fatalf("only %d vectors", len(v.Syntactic))
	}
	for _, tc := range v.Syntactic {
		got := Check(tc.URL)
		if got.Allowed != tc.Allowed || got.Reason != tc.Reason {
			t.Errorf("Check(%q) = %+v, Node says allowed=%v %q", tc.URL, got, tc.Allowed, tc.Reason)
		}
	}
}

// Node reads these as valid URLs; Go refuses them, which only errs on the safe side.
func TestCheckRefusesWhatNodeParsesLeniently(t *testing.T) {
	for _, raw := range []string{"http:example.com", "http:/example.com", `http://example.com\@evil.com`} {
		if got := Check(raw); got.Allowed {
			t.Errorf("Check(%q) allowed", raw)
		}
	}
}

func TestCheckerMatchesNode(t *testing.T) {
	for _, tc := range loadVectors(t).DNS {
		lookup := func(ctx context.Context, host string) ([]netip.Addr, error) {
			switch {
			case tc.Error == nil:
				var out []netip.Addr
				for _, a := range tc.Addresses {
					out = append(out, netip.MustParseAddr(a))
				}
				return out, nil
			case *tc.Error == "ENOTFOUND":
				return nil, &net.DNSError{Err: "no such host", Name: host, IsNotFound: true}
			case *tc.Error == "EAI_AGAIN":
				return nil, &net.DNSError{Err: "try again", Name: host, IsTemporary: true}
			case *tc.Error == "DNS_TIMEOUT":
				<-ctx.Done()
				return nil, ctx.Err()
			}
			return nil, errors.New("lookup failed")
		}
		got, err := Checker{Lookup: lookup, Timeout: 50 * time.Millisecond}.Validate(context.Background(), tc.URL)
		if err != nil || got.Allowed != tc.Allowed || got.Reason != tc.Reason {
			t.Errorf("Validate(%q) = %+v, %v; Node says allowed=%v %q", tc.URL, got, err, tc.Allowed, tc.Reason)
		}
	}
}

func TestCheckerStopsWhenCallerGivesUp(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := (Checker{}).Validate(ctx, "https://example.com"); !errors.Is(err, context.Canceled) {
		t.Fatalf("got %v", err)
	}
}

func TestValidHTTPURL(t *testing.T) {
	for raw, want := range map[string]bool{
		"https://api.example.com/v1": true, "http://8.8.8.8:8080": true, "http://localhost:11434": true,
		"ftp://example.com": false, "example.com": false, "https://": false, "javascript:alert(1)": false,
		"https://user@example.com": false, "https://user:pw@example.com": false, "": false,
	} {
		if got := ValidHTTPURL(raw); got != want {
			t.Errorf("ValidHTTPURL(%q) = %v", raw, got)
		}
	}
}
