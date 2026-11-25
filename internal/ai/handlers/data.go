package handlers

import (
	"context"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var dataHandlers = map[string]handler{
	"read_health_data":     readHealthData,
	"social_video_extract": socialVideoExtract,
	"social_reach_status":  socialReachStatus,
	"social_reach_read":    socialReachRead,
	"social_reach_search":  socialReachSearch,
}

func readHealthData(ctx context.Context, c *call) (any, error) {
	if c.b.d.Health == nil {
		return nil, errorf("Health data is unavailable.")
	}
	return c.b.d.Health.Read(ctx, c.run.UserID, c.args["metric_type"], c.args["limit"])
}

func socialVideoExtract(ctx context.Context, c *call) (any, error) {
	if c.b.d.SocialVideo == nil {
		return errResult("Social video extraction service is unavailable."), nil
	}
	source := strings.TrimSpace(str(c.args["url"]))
	if source == "" {
		return errResult("url is required"), nil
	}
	return c.b.d.SocialVideo.Extract(ctx, c.run.UserID, c.run.AgentID, source, c.args["include_frame"] != false, c.args["force_stt"] == true)
}

const noSocialReach = "Social reach service is unavailable."

func socialReachStatus(ctx context.Context, c *call) (any, error) {
	if c.b.d.SocialReach == nil {
		return errResult(noSocialReach), nil
	}
	return c.b.d.SocialReach.Status(ctx, c.run.UserID)
}

func socialReachRead(ctx context.Context, c *call) (any, error) {
	if c.b.d.SocialReach == nil {
		return errResult(noSocialReach), nil
	}
	return c.b.d.SocialReach.Read(ctx, c.run.UserID, orMap(c.args))
}

func socialReachSearch(ctx context.Context, c *call) (any, error) {
	if c.b.d.SocialReach == nil {
		return errResult(noSocialReach), nil
	}
	return c.b.d.SocialReach.Search(ctx, c.run.UserID, orMap(c.args))
}

func orMap(m dyn.Map) dyn.Map {
	if m == nil {
		return dyn.Map{}
	}
	return m
}
