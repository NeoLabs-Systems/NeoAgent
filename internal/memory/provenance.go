package memory

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"

	"golang.org/x/text/unicode/norm"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

// Where a memory came from decides how the model may use it:
//
//	verified:   the user said it, or a tool result in the same run showed it
//	retrieved:  stored from somewhere else or never checked: mail, documents,
//	            imports, shared rooms, the agent's own notes, older rows
//	assumption: inferred by a model and never confirmed
const lowConfidence = 0.5

func isVerifiedTrust(trustLevel any) bool {
	s, _ := trustLevel.(string)
	return s == "user_stated" || s == "tool_observed"
}

// OwnerVerification is the receipt that the owner stated or checked content.
func OwnerVerification(content string) *jsx.Obj {
	sum := sha256.Sum256([]byte(jsx.Trim(content)))
	return jsx.O("source", "owner", "digest", hex.EncodeToString(sum[:]))
}

// Provenance classifies a stored memory as verified, retrieved or assumption.
// confidence is nil when the memory has none.
func Provenance(content string, confidence *float64, metadata *jsx.Obj) string {
	if metadata == nil {
		metadata = jsx.NewObj()
	}
	if metadata.Value("trustLevel") == "model_inference" || metadata.Value("relation") == "derives" {
		return "assumption"
	}
	if isVerifiedTrust(metadata.Value("trustLevel")) {
		if verification, ok := metadata.Value("verification").(*jsx.Obj); ok &&
			verification.Value("source") == "owner" &&
			verification.Value("digest") == OwnerVerification(content).Value("digest") {
			return "verified"
		}
	}
	if confidence != nil && *confidence < lowConfidence {
		return "assumption"
	}
	return "retrieved"
}

// MergeMemoryMetadata merges a restatement into stored metadata. A restatement
// from a weaker source does not demote what a stronger one established, and
// the user confirming an inference settles it.
func MergeMemoryMetadata(existing, incoming *jsx.Obj) *jsx.Obj {
	merged := existing.Clone().Assign(incoming)
	switch {
	case isVerifiedTrust(existing.Value("trustLevel")) && !isVerifiedTrust(incoming.Value("trustLevel")):
		merged.Set("trustLevel", existing.Lookup("trustLevel"))
		merged.Set("relation", existing.Lookup("relation"))
		if existing.Lookup("relation") == jsx.Undefined {
			merged.Delete("relation")
		}
	case isVerifiedTrust(incoming.Value("trustLevel")) && merged.Value("relation") == "derives":
		merged.Set("relation", "new")
	}
	return merged
}

func nfcCollapse(value string) string {
	return jsx.Trim(jsx.ReplaceSpaceRuns(norm.NFC.String(value)))
}

// StatementInText: exact, complete authored text is evidence of what was
// stated. Word overlap and model-supplied quotes cannot verify a paraphrase.
func StatementInText(text, statement string) bool {
	return nfcCollapse(statement) != "" && nfcCollapse(text) == nfcCollapse(statement)
}

// Message is one turn of a thread.
type Message struct {
	Role    string
	Content string
}

// KeepSupportedStatements keeps the statements a user message states exactly.
func KeepSupportedStatements(statements []string, messages []Message) []string {
	var authored []string
	for _, m := range messages {
		if m.Role == "user" {
			authored = append(authored, m.Content)
		}
	}
	var kept []string
	for _, statement := range statements {
		for _, text := range authored {
			if StatementInText(text, statement) {
				kept = append(kept, statement)
				break
			}
		}
	}
	return kept
}

// GroundedCandidate is an extracted candidate that survived grounding.
type GroundedCandidate struct {
	Candidate  Candidate
	TrustLevel string
}

func nfcLower(value string) string {
	return jsx.Lower(nfcCollapse(value))
}

// GroundMemoryCandidates keeps candidates whose evidence quote is words the
// thread holds, said by the owner or returned by a tool. Without a quote the
// candidate stays an assumption. toolResults are strings or JSON-encodable
// values.
func GroundMemoryCandidates(candidates []Candidate, messages []Message, toolResults []any) (grounded []GroundedCandidate, dropped int) {
	var haystack []string
	for _, m := range messages {
		if m.Role == "user" {
			haystack = append(haystack, nfcLower(m.Content))
		}
	}
	for _, result := range toolResults {
		text, ok := result.(string)
		if !ok {
			text = jsx.Marshal(result)
		}
		haystack = append(haystack, nfcLower(text))
	}
	for _, candidate := range candidates {
		quote := nfcLower(candidate.Evidence)
		if quote != "" && !anyContains(haystack, quote) {
			dropped++
			continue
		}
		confidence := candidate.Confidence
		if confidence == 0 {
			confidence = lowConfidence
		}
		candidate.Relation = "derives"
		candidate.Confidence = min(confidence, lowConfidence)
		grounded = append(grounded, GroundedCandidate{Candidate: candidate, TrustLevel: "model_inference"})
	}
	return grounded, dropped
}

func anyContains(texts []string, quote string) bool {
	for _, text := range texts {
		if strings.Contains(text, quote) {
			return true
		}
	}
	return false
}
