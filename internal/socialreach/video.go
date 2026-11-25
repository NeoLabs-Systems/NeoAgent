package socialreach

import (
	"context"
	"encoding/json"

	"github.com/NeoLabs-Systems/neoagent/internal/socialvideo"
)

type videoChannel struct {
	base
	video socialvideo.Extractor
}

func newVideo(v socialvideo.Extractor) *videoChannel {
	return &videoChannel{base{platforms["social_video"]}, v}
}

var videoLabels = map[string]string{"youtube": "YouTube", "tiktok": "TikTok", "instagram": "Instagram/Reels", "x": "X"}

func (c *videoChannel) canHandleURL(raw string) bool {
	_, err := socialvideo.NormalizeAndDetect(raw)
	return err == nil
}

func (c *videoChannel) check(ctx context.Context, _ int64) (obj, error) {
	s := c.baseStatus()
	if c.video == nil {
		s.set("ready", false)
		s.set("status", "warn")
		s.set("activeBackend", nil)
		s.set("message", "Social video extraction is not connected right now.")
		return s, nil
	}
	health, err := c.video.HealthStatus(ctx, false)
	var setup any = health
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		health = socialvideo.Health{}
		setup = obj{{"ready", false}, {"dependencies", []any{}}, {"error", err.Error()}}
	}
	var missing []string
	for _, d := range health.Dependencies {
		if d.Required && !d.Available && d.Name != "" {
			missing = append(missing, d.Name)
		}
	}
	s.set("ready", health.Ready)
	s.set("activeBackend", "social_video_extractor")
	if health.Ready {
		s.set("status", "ok")
		s.set("message", "Reads YouTube, TikTok, Instagram/Reels, and X video links with the existing social video extractor.")
	} else {
		names := "the video tools"
		if len(missing) > 0 {
			names = joinAnd(missing)
		}
		s.set("status", "warn")
		s.set("message", "Install "+names+" to extract social video links.")
	}
	s.set("setup", setup)
	return s, nil
}

func joinAnd(names []string) string {
	out := names[0]
	for _, n := range names[1:] {
		out += " and " + n
	}
	return out
}

func (c *videoChannel) read(ctx context.Context, a readArgs) (any, error) {
	if c.video == nil {
		return nil, &reachError{503, "Social video extraction is not connected right now."}
	}
	detected, err := socialvideo.NormalizeAndDetect(str(a.get("url")))
	if err != nil {
		return nil, &reachError{500, err.Error()}
	}
	result, err := c.video.Extract(ctx, a.userID, detected.NormalizedURL, socialvideo.Options{
		IncludeFrame: a.get("include_frame") != false,
		ForceSTT:     a.get("force_stt") == true,
		AgentID:      str(a.get("agentId")),
	})
	if err != nil {
		return nil, err
	}
	raw, err := json.Marshal(result)
	if err != nil {
		return nil, err
	}
	out, err := orderedFromJSON(raw)
	if err != nil {
		return nil, err
	}
	out.set("platform", c.ID)
	label := videoLabels[detected.Platform]
	if label == "" {
		label = detected.Platform
	}
	out.set("videoPlatform", detected.Platform)
	out.set("label", label)
	out.set("source", "social_video_extractor")
	return out, nil
}
