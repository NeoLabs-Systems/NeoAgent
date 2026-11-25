package handlers

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"math"
	"strconv"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/files"
)

var mediaHandlers = map[string]handler{
	"generate_image":   generateImage,
	"generate_table":   generateTable,
	"generate_graph":   generateGraph,
	"analyze_image":    analyzeImage,
	"transcribe_audio": transcribeAudio,
	"ocr_extract":      ocrExtract,
}

func generateImage(ctx context.Context, c *call) (any, error) {
	if c.b.d.Artifacts == nil {
		return errResult("Artifact storage is unavailable."), nil
	}
	n := jsNumber(c.args["n"])
	if math.IsNaN(n) || n == 0 {
		n = 1
	}
	count := int(math.Min(n, 4))
	prompt := str(c.args["prompt"])
	var images []string
	served := false
	var err error
	if c.b.d.Router != nil {
		images, served, err = c.b.d.Router.GenerateImages(ctx, c.run.UserID, c.run.AgentID, prompt, count)
	}
	if err == nil && !served {
		if c.b.d.Media == nil {
			err = errors.New("Image generation is unavailable.")
		} else {
			images, err = c.b.d.Media.GenerateImagesXAI(ctx, prompt, count)
		}
	}
	if err != nil {
		return failure(ctx, err)
	}
	artifacts := []any{}
	paths := []any{}
	for _, b64 := range images {
		content, decodeErr := base64.StdEncoding.DecodeString(b64)
		if decodeErr != nil {
			return failure(ctx, decodeErr)
		}
		stored, err := c.b.d.Artifacts.CreateBuffer(ctx, c.run.UserID, NewArtifact{
			Kind: "generated-image", FilenameBase: "generated-image", Extension: "png", ContentType: "image/png", Content: content,
		})
		if err != nil {
			return failure(ctx, err)
		}
		artifacts = append(artifacts, dyn.Ordered{{Key: "artifactId", Value: stored.ArtifactID}, {Key: "path", Value: stored.URL}})
		paths = append(paths, stored.URL)
	}
	return dyn.Ordered{
		{Key: "success", Value: true},
		{Key: "artifacts", Value: artifacts},
		{Key: "paths", Value: paths},
		{Key: "count", Value: len(artifacts)},
		{Key: "message", Value: fmt.Sprintf("Generated %d image(s). Use send_message with media_path to share.", len(artifacts))},
	}, nil
}

func generateTable(_ context.Context, c *call) (any, error) {
	return dyn.Ordered{{Key: "result", Value: c.args["markdown_table"]}, {Key: "instruction", Value: "Table generated. Please output this table directly to the user in your next message."}}, nil
}

func generateGraph(_ context.Context, c *call) (any, error) {
	return dyn.Ordered{{Key: "result", Value: "```mermaid\n" + jsText(c.args["mermaid_code"]) + "\n```"}, {Key: "instruction", Value: "Graph generated. Please output this mermaid block directly to the user in your next message."}}, nil
}

func (c *call) resolveUserFile(ctx context.Context, reference any, label string) (string, error) {
	return ResolveUserFile(ctx, c.b.d.Artifacts, c.b.d.Workspace, c.run.UserID, reference, label)
}

// ResolveUserFile maps a workspace path, owned artifact id or artifact URL to
// a host file (files/user_file_access.js).
func ResolveUserFile(ctx context.Context, store Artifacts, ws Workspace, userID int64, reference any, label string) (string, error) {
	var refs files.ArtifactStore
	if store != nil {
		refs = artifactRefs{ctx: ctx, store: store}
	}
	var paths files.Workspace
	if ws != nil {
		paths = workspaceRefs{ws: ws}
	}
	return files.ResolveReference(userID, dyn.Str(reference), refs, paths, label)
}

type artifactRefs struct {
	ctx   context.Context
	store Artifacts
}

func (a artifactRefs) StoragePath(userID int64, id string) (string, bool) {
	path, _, ok, err := a.store.StoragePath(a.ctx, userID, id)
	return path, ok && err == nil
}

func (a artifactRefs) StoragePathByFile(userID int64, reference string) (string, bool) {
	path, ok, err := a.store.ByStoragePath(a.ctx, userID, reference)
	return path, ok && err == nil
}

type workspaceRefs struct{ ws Workspace }

func (w workspaceRefs) ResolvePath(userKey, candidate, label string) (string, error) {
	id, err := strconv.ParseInt(userKey, 10, 64)
	if err != nil {
		return "", err
	}
	return w.ws.ResolvePath(id, candidate, label)
}

func analyzeImage(ctx context.Context, c *call) (any, error) {
	path, err := c.resolveUserFile(ctx, c.args["image_path"], "Image")
	if err != nil {
		return failure(ctx, err)
	}
	if c.b.d.Media == nil {
		return errResult("No vision-capable model is currently available in the live provider catalogs."), nil
	}
	question := orString(c.args["question"], "Describe this image in detail.")
	result, err := c.b.d.Media.AnalyzeImage(ctx, c.run.UserID, c.run.AgentID, path, question)
	if err != nil {
		return failure(ctx, err)
	}
	return result, nil
}

func transcribeAudio(ctx context.Context, c *call) (any, error) {
	path, err := c.resolveUserFile(ctx, c.args["audio_path"], "Audio")
	if err != nil {
		return failure(ctx, err)
	}
	if c.b.d.Media == nil {
		return errResult("Speech-to-text is unavailable."), nil
	}
	transcript, err := c.b.d.Media.Transcribe(ctx, c.run.UserID, c.run.AgentID, path)
	if err != nil {
		return failure(ctx, err)
	}
	return dyn.Map{"transcript": transcript}, nil
}

func ocrExtract(ctx context.Context, c *call) (any, error) {
	path, err := c.resolveUserFile(ctx, c.args["image_path"], "OCR image")
	if err != nil {
		return failure(ctx, err)
	}
	if c.b.d.Media == nil {
		return errResult("OCR is unavailable."), nil
	}
	text, confidence, err := c.b.d.Media.OCR(ctx, path)
	if err != nil {
		return failure(ctx, err)
	}
	return dyn.Ordered{{Key: "text", Value: text}, {Key: "confidence", Value: confidence}}, nil
}
