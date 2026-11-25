package agent

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// ImageMIMEType is the media type of an image file by its extension.
func ImageMIMEType(path, override string) string {
	if o := strings.ToLower(strings.TrimSpace(override)); o != "" {
		return o
	}
	switch strings.ToLower(filepath.Ext(path)) {
	case ".png":
		return "image/png"
	case ".gif":
		return "image/gif"
	case ".webp":
		return "image/webp"
	}
	return "image/jpeg"
}

// ImageAnalysis is a vision model's description of an image.
type ImageAnalysis struct {
	Description string `json:"description"`
	Model       any    `json:"model"`
	Provider    string `json:"provider"`
}

// AnalyzeImage asks a vision-capable model about an image: the account's
// default model first, then one model of every other available provider.
func (e *Engine) AnalyzeImage(ctx context.Context, userID int64, agentID, imagePath, imageBase64, mimeType, question string) (ImageAnalysis, error) {
	encoded := strings.TrimSpace(imageBase64)
	if encoded == "" {
		data, err := os.ReadFile(imagePath)
		if err != nil {
			return ImageAnalysis{}, fmt.Errorf("File not found: %s", imagePath)
		}
		encoded = base64.StdEncoding.EncodeToString(data)
	} else if len(encoded) > 8*1024*1024 {
		return ImageAnalysis{}, errors.New("Image payload exceeds the analysis limit.")
	}
	if question == "" {
		question = "Describe this image in detail."
	}
	type candidate struct {
		providerName, model string
		provider            llm.Provider
	}
	var attempted []string
	var candidates []candidate
	if preferred, err := e.selectModel(ctx, userID, agentID, false, "", aimodels.Hint{}, nil); err == nil {
		candidates = append(candidates, candidate{preferred.ProviderName, preferred.Model, preferred.Provider})
	} else {
		if ctx.Err() != nil {
			return ImageAnalysis{}, ctx.Err()
		}
		attempted = append(attempted, "default-provider lookup failed: "+err.Error())
	}
	if catalog, err := e.deps.Models.Catalog(ctx, userID, agentID); err == nil {
		for _, m := range catalog {
			if !m.Available {
				continue
			}
			seen := false
			for _, c := range candidates {
				seen = seen || c.providerName == m.Provider
			}
			if seen {
				continue
			}
			provider, err := e.deps.Models.Provider(ctx, userID, agentID, m)
			if err != nil {
				attempted = append(attempted, m.Provider+": "+err.Error())
				continue
			}
			candidates = append(candidates, candidate{m.Provider, m.ModelID, provider})
		}
	} else {
		attempted = append(attempted, "live model discovery failed: "+err.Error())
	}
	mime := ImageMIMEType(imagePath, mimeType)
	policy := llm.RetryPolicyFromEnv(e.deps.Getenv)
	for _, c := range candidates {
		analyzer, ok := c.provider.(llm.ImageAnalyzer)
		if !ok || !c.provider.SupportsVision() {
			attempted = append(attempted, c.providerName+": image analysis is not supported by this provider integration")
			continue
		}
		text, err := llm.Retry(ctx, policy, func(int) (string, error) {
			return analyzer.AnalyzeImage(ctx, llm.ImageRequest{Model: c.model, Prompt: question, ImageB64: encoded, MIMEType: mime})
		})
		if err == nil {
			return ImageAnalysis{Description: strings.TrimSpace(text), Model: c.model, Provider: c.providerName}, nil
		}
		if ctx.Err() != nil {
			return ImageAnalysis{}, ctx.Err()
		}
		attempted = append(attempted, c.providerName+": "+err.Error())
	}
	if len(attempted) > 0 {
		return ImageAnalysis{}, errors.New("Image analysis failed. " + strings.Join(attempted, " | "))
	}
	return ImageAnalysis{}, errors.New("No vision-capable model is currently available in the live provider catalogs.")
}
