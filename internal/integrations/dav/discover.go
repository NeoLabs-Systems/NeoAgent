package dav

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

const maxRedirects = 3

// Auth is HTTP Basic credentials.
type Auth struct{ Username, Password string }

func (a Auth) header() string {
	return "Basic " + base64.StdEncoding.EncodeToString([]byte(a.Username+":"+a.Password))
}

// Location is a discovered home: the server origin and the home path.
type Location struct {
	Origin string `json:"origin"`
	Home   string `json:"home"`
}

type collection struct{ label, wellKnown, namespace, homeSet string }

var kinds = map[string]collection{
	"caldav":  {"CalDAV URL", "/.well-known/caldav", "urn:ietf:params:xml:ns:caldav", "calendar-home-set"},
	"carddav": {"CardDAV URL", "/.well-known/carddav", "urn:ietf:params:xml:ns:carddav", "addressbook-home-set"},
}

// sameSite allows a hop to a sibling host of the same site, over HTTPS only
// (iCloud answers on pNN-caldav.icloud.com).
func sameSite(from, to *url.URL) bool {
	if origin(from) == origin(to) {
		return true
	}
	if to.Scheme != "https" {
		return false
	}
	site := func(host string) string {
		parts := strings.Split(host, ".")
		if len(parts) > 2 {
			parts = parts[len(parts)-2:]
		}
		return strings.Join(parts, ".")
	}
	return site(from.Hostname()) == site(to.Hostname())
}

func origin(u *url.URL) string { return u.Scheme + "://" + u.Host }

func fetch(ctx context.Context, client *oauthclient.Client, target string, auth Auth, r Request) (*oauthclient.Response, error) {
	method := r.Method
	if method == "" {
		method = "PROPFIND"
	}
	accept := r.Accept
	if accept == "" {
		accept = "application/xml, text/xml, */*"
	}
	header := map[string]string{"Authorization": auth.header(), "Accept": accept}
	for k, v := range r.Headers {
		header[k] = v
	}
	var body []byte
	if r.Body != "" {
		body = []byte(r.Body)
	}
	return client.Do(ctx, oauthclient.Request{Method: method, URL: target, Header: header, Body: body})
}

type found struct {
	url *url.URL
	xml string
}

func propfind(ctx context.Context, client *oauthclient.Client, start *url.URL, auth Auth, prop, namespace string) (*found, error) {
	current := start
	for hop := 0; hop <= maxRedirects; hop++ {
		resp, err := fetch(ctx, client, current.String(), auth, Request{
			Headers: map[string]string{"Depth": "0", "Content-Type": "application/xml; charset=utf-8"},
			Body:    "<?xml version=\"1.0\"?>\n<d:propfind xmlns:d=\"DAV:\" xmlns:c=\"" + namespace + "\"><d:prop>" + prop + "</d:prop></d:propfind>",
		})
		if err != nil {
			return nil, err
		}
		if resp.Status >= 300 && resp.Status < 400 {
			next, err := current.Parse(resp.Header.Get("Location"))
			if err != nil || !sameSite(current, next) {
				return nil, errors.New("The server redirected to a different site.")
			}
			current = next
			continue
		}
		if resp.Status == 401 {
			return nil, errors.New("The server rejected the email address or app password.")
		}
		if resp.Status < 200 || resp.Status > 299 {
			return nil, nil
		}
		return &found{url: current, xml: string(resp.Body)}, nil
	}
	return nil, errors.New("The server redirected too many times.")
}

func hrefIn(xml, property string) string { return XMLText(XMLText(xml, property), "href") }

// Discover finds the calendar or address book home of an account (RFC 6764):
// the URL given, then its well-known path, then the principal it names.
func Discover(ctx context.Context, client *oauthclient.Client, serverURL any, kind string, auth Auth) (*Location, error) {
	c := kinds[kind]
	normalized, err := NormalizeServerURL(serverURL, c.label)
	if err != nil {
		return nil, err
	}
	base, err := url.Parse(normalized)
	if err != nil {
		return nil, err
	}
	homeProp := "<c:" + c.homeSet + "/>"
	wellKnown, _ := base.Parse(c.wellKnown)
	for _, candidate := range []*url.URL{base, wellKnown} {
		root, err := propfind(ctx, client, candidate, auth, "<d:current-user-principal/>"+homeProp, c.namespace)
		if err != nil {
			return nil, err
		}
		if root == nil {
			continue
		}
		homeHref := hrefIn(root.xml, c.homeSet)
		from := root.url
		if homeHref == "" {
			principalHref := hrefIn(root.xml, "current-user-principal")
			if principalHref == "" {
				continue
			}
			principalURL, err := root.url.Parse(principalHref)
			if err != nil {
				continue
			}
			if !sameSite(root.url, principalURL) {
				return nil, errors.New("The server named a principal on a different site.")
			}
			principal, err := propfind(ctx, client, principalURL, auth, homeProp, c.namespace)
			if err != nil {
				return nil, err
			}
			from = principalURL
			if principal != nil {
				homeHref = hrefIn(principal.xml, c.homeSet)
				from = principal.url
			}
		}
		if homeHref == "" {
			continue
		}
		home, err := from.Parse(homeHref)
		if err != nil {
			continue
		}
		if !sameSite(base, home) {
			return nil, errors.New("The server named a home on a different site.")
		}
		return &Location{Origin: origin(home), Home: strings.TrimRight(home.EscapedPath(), "/") + "/"}, nil
	}
	what := "address books"
	if kind == "caldav" {
		what = "calendars"
	}
	return nil, fmt.Errorf("No %s were found at %s.", what, base.Host)
}

// NewStore is the store over a discovered home.
func NewStore(client *oauthclient.Client, loc Location, auth Auth) Store {
	return Store{Home: loc.Home, Do: func(ctx context.Context, path string, r Request) (string, error) {
		base, err := url.Parse(loc.Origin)
		if err != nil {
			return "", err
		}
		target, err := base.Parse(path)
		if err != nil || origin(target) != loc.Origin {
			return "", errors.New("DAV path must stay on the connected server.")
		}
		resp, err := fetch(ctx, client, target.String(), auth, r)
		if err != nil {
			return "", err
		}
		if resp.Status >= 300 && resp.Status < 400 {
			return "", errors.New("The DAV server redirected the request; redirects are not followed.")
		}
		if resp.Status < 200 || resp.Status > 299 {
			return "", fmt.Errorf("DAV request failed (%d): %s", resp.Status, sliceUTF16(string(resp.Body), 300))
		}
		return string(resp.Body), nil
	}}
}

// sliceUTF16 is String.prototype.slice(0, n).
func sliceUTF16(s string, n int) string {
	units := 0
	for i, r := range s {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if units+w > n {
			return s[:i]
		}
		units += w
	}
	return s
}
