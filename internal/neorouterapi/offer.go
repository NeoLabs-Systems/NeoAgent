package neorouterapi

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"sync"
	"time"
)

const offerCacheTTL = 5 * time.Minute

var roleTypes = []struct {
	role string
	typ  string
}{
	{"chat", "chat"},
	{"system_one", "moderation"},
	{"transcription", "transcription"},
	{"live", "live"},
	{"embeddings", "embedding"},
	{"images", "image"},
	{"search", "search"},
}

// Offer describes what a NeoRouter connection can do per role.
type Offer struct {
	Roles         map[string]int `json:"roles"`
	NotAllowed    map[string]int `json:"notAllowed"`
	LiveProtocols []string       `json:"liveProtocols"`
}

type cachedOffer struct {
	offer     *Offer
	expiresAt time.Time
}

func offerCacheKey(conn *Connection) string {
	sum := sha256.Sum256([]byte(conn.APIBase + "\n" + conn.APIKey))
	return hex.EncodeToString(sum[:])
}

// DescribeOffer queries (or returns cached) capabilities for conn across all roles.
func (s *Service) DescribeOffer(ctx context.Context, conn *Connection, fresh bool) (*Offer, error) {
	if conn == nil {
		return nil, nil
	}
	key := offerCacheKey(conn)
	if !fresh {
		s.offerMu.Lock()
		cached, ok := s.offerCache[key]
		s.offerMu.Unlock()
		if ok && cached.expiresAt.After(s.now()) {
			return cached.offer, nil
		}
	}

	offer, err := s.loadOffer(ctx, conn)
	if err != nil {
		return nil, err
	}
	s.offerMu.Lock()
	s.offerCache[key] = cachedOffer{offer: offer, expiresAt: s.now().Add(offerCacheTTL)}
	s.offerMu.Unlock()
	return offer, nil
}

func (s *Service) loadOffer(ctx context.Context, conn *Connection) (*Offer, error) {
	var (
		mu            sync.Mutex
		wg            sync.WaitGroup
		roles         = make(map[string]int, len(roleTypes))
		notAllowed    = make(map[string]int, len(roleTypes))
		liveProtoSeen = make(map[string]bool)
		liveProtocols = []string{}
		firstErr      error
	)

	for _, rt := range roleTypes {
		wg.Add(1)
		go func(role, typ string) {
			defer wg.Done()
			list, err := s.ModelList(ctx, conn, typ)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				if firstErr == nil {
					firstErr = err
				}
				return
			}
			var count int
			for _, m := range list.Models {
				if strings.HasPrefix(m.ID, "auto") {
					continue
				}
				if role == "system_one" && !IsDecisionModel(m) {
					continue
				}
				count++
				if role == "live" && m.NeoRouter != nil {
					for _, proto := range m.NeoRouter.Protocols {
						if !liveProtoSeen[proto] {
							liveProtoSeen[proto] = true
							liveProtocols = append(liveProtocols, proto)
						}
					}
				}
			}
			roles[role] = count
			if role == "system_one" {
				if dm := list.NotAllowed.DecisionModels; dm != nil {
					notAllowed[role] = dm.Free + dm.Plan + dm.Paid
				} else {
					notAllowed[role] = 0
				}
			} else {
				notAllowed[role] = list.NotAllowed.Free + list.NotAllowed.Plan + list.NotAllowed.Paid
			}
		}(rt.role, rt.typ)
	}
	wg.Wait()

	if firstErr != nil && len(roles) == 0 {
		return nil, firstErr
	}
	return &Offer{
		Roles:         roles,
		NotAllowed:    notAllowed,
		LiveProtocols: liveProtocols,
	}, nil
}
