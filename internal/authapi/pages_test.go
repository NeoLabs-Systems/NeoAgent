package authapi

import (
	"encoding/json"
	"net/http/httptest"
	"os"
	"testing"
)

type pageVectors struct {
	Conf []struct {
		Arg struct {
			Ok             bool
			Title, Message string
		}
		Out struct {
			Status int
			Body   string
		}
	}
	Reset []struct {
		Arg struct {
			Token, Error string
			Success      bool
		}
		Out struct {
			Status int
			Body   string
		}
	}
}

func TestPagesMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/pages.json")
	if err != nil {
		t.Fatal(err)
	}
	var v pageVectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	for i, c := range v.Conf {
		rec := httptest.NewRecorder()
		sendEmailConfirmationPage(rec, c.Arg.Ok, c.Arg.Title, c.Arg.Message)
		if rec.Code != c.Out.Status || rec.Body.String() != c.Out.Body {
			t.Errorf("confirmation page %d: status %d/%d\n%s", i, rec.Code, c.Out.Status, firstDiff(rec.Body.String(), c.Out.Body))
		}
	}
	for i, c := range v.Reset {
		rec := httptest.NewRecorder()
		sendPasswordResetPage(rec, c.Arg.Token, c.Arg.Error, c.Arg.Success)
		if rec.Code != c.Out.Status || rec.Body.String() != c.Out.Body {
			t.Errorf("reset page %d: status %d/%d\n%s", i, rec.Code, c.Out.Status, firstDiff(rec.Body.String(), c.Out.Body))
		}
	}
}

func firstDiff(a, b string) string {
	n := len(a)
	if len(b) < n {
		n = len(b)
	}
	for i := 0; i < n; i++ {
		if a[i] != b[i] {
			lo, hi := max(i-50, 0), min(i+70, n)
			return "at " + string(rune('0'+i%10)) + ":\n got:  " + a[lo:hi] + "\n want: " + b[lo:hi]
		}
	}
	return "length differs (prefix equal)"
}
