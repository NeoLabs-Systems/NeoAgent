package handlers

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var sharingHandlers = map[string]handler{"share_web_page": shareWebPage}

func shareWebPage(ctx context.Context, c *call) (any, error) {
	shares := c.b.d.WebShares
	action := str(c.args["action"])
	if shares == nil && (action == "share" || action == "stop" || action == "list") {
		return errResult("Web page sharing is unavailable."), nil
	}
	switch action {
	case "share":
		return shares.Share(ctx, c.run.UserID, c.run.AgentID, c.args["name"], c.args["port"])
	case "stop":
		return shares.Stop(ctx, c.run.UserID, c.args["name"])
	case "list":
		pages, err := shares.List(ctx, c.run.UserID)
		if err != nil {
			return nil, err
		}
		return dyn.Map{"shared_pages": pages}, nil
	}
	return errResult("action must be share, stop or list."), nil
}
