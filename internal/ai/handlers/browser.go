package handlers

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var browserHandlers = map[string]handler{
	"browser_navigate":          browserNavigate,
	"browser_click":             browserClick,
	"browser_type":              browserType,
	"browser_act":               browserAct,
	"browser_extract":           browserExtract,
	"browser_screenshot":        browserScreenshot,
	"browser_evaluate":          browserEvaluate,
	"credential_fill_browser":   credentialFill,
	"credential_submit_browser": credentialSubmit,
	"credential_cancel_browser": credentialCancel,
	"credential_http_request":   credentialHTTP,
}

// browser resolves the run's browser provider.
func (c *call) browser(ctx context.Context) (Browser, string, error) {
	rt := c.b.d.Runtime
	if rt == nil {
		return nil, "", errorf("Browser provider is unavailable. VM runtime is required.")
	}
	return rt.Browser(ctx, c.run.UserID, c.run.DeviceTarget)
}

// withBackend is {...result, backend}.
func withBackend(result dyn.Map, backend string) dyn.Ordered {
	return spread(result, dyn.Ordered{{Key: "backend", Value: backend}})
}

func (c *call) checkURL(ctx context.Context, url any) (dyn.Map, bool) {
	if c.b.d.URLCheck == nil {
		return nil, true
	}
	allowed, reason := c.b.d.URLCheck(ctx, str(url))
	if !allowed {
		return dyn.Map{"error": reason, "url": url}, false
	}
	return nil, true
}

// browserCall resolves the browser and runs one provider call. A provider
// failure is thrown, as in Node.
func browserCall(ctx context.Context, c *call, run func(Browser) (dyn.Map, error)) (any, error) {
	provider, backend, err := c.browser(ctx)
	if err != nil {
		return nil, err
	}
	if provider == nil {
		return errResult("Browser controller not available"), nil
	}
	result, err := run(provider)
	if err != nil {
		return nil, err
	}
	return withBackend(result, backend), nil
}

func browserNavigate(ctx context.Context, c *call) (any, error) {
	if refusal, ok := c.checkURL(ctx, c.args["url"]); !ok {
		return refusal, nil
	}
	return browserCall(ctx, c, func(p Browser) (dyn.Map, error) {
		return p.Navigate(ctx, str(c.args["url"]), dyn.Map{
			"screenshot":     c.args["screenshot"] != false,
			"waitFor":        c.args["waitFor"],
			"fullPage":       c.args["fullPage"],
			"referrerMode":   c.args["referrerMode"],
			"challengeRetry": c.args["challengeRetry"],
		})
	})
}

func browserClick(ctx context.Context, c *call) (any, error) {
	return browserCall(ctx, c, func(p Browser) (dyn.Map, error) {
		return p.Click(ctx, c.args["selector"], c.args["text"], c.args["screenshot"] != false)
	})
}

func browserType(ctx context.Context, c *call) (any, error) {
	return browserCall(ctx, c, func(p Browser) (dyn.Map, error) {
		return p.Type(ctx, c.args["selector"], c.args["text"], dyn.Map{
			"clear":      c.args["clear"] != false,
			"pressEnter": c.args["pressEnter"],
		})
	})
}

func browserExtract(ctx context.Context, c *call) (any, error) {
	return browserCall(ctx, c, func(p Browser) (dyn.Map, error) {
		return p.Extract(ctx, c.args["selector"], c.args["attribute"], c.args["all"])
	})
}

func browserScreenshot(ctx context.Context, c *call) (any, error) {
	return browserCall(ctx, c, func(p Browser) (dyn.Map, error) {
		return p.Screenshot(ctx, dyn.Map{"fullPage": c.args["fullPage"], "selector": c.args["selector"]})
	})
}

func browserEvaluate(ctx context.Context, c *call) (any, error) {
	provider, backend, err := c.browser(ctx)
	if err != nil {
		return nil, err
	}
	if provider == nil {
		return errResult("Browser controller not available"), nil
	}
	script := c.args["script"]
	if script == nil {
		script = c.args["javascript"]
	}
	if !dyn.Truthy(script) {
		return errResult(`browser_evaluate requires a "script" argument`), nil
	}
	result, err := provider.Evaluate(ctx, dyn.String(script))
	if err != nil {
		return nil, err
	}
	return withBackend(result, backend), nil
}

func browserAct(ctx context.Context, c *call) (any, error) {
	goal, _ := c.args["goal"].(string)
	goal = trimSpaceJS(goal)
	if goal == "" {
		return errResult(`browser_act requires a "goal" argument`), nil
	}
	s1 := c.b.d.SystemOne
	ready := false
	if s1 != nil {
		var err error
		if ready, err = s1.Ready(ctx, c.run.UserID, c.run.AgentID); err != nil && ctx.Err() != nil {
			return nil, ctx.Err()
		}
	}
	if !ready {
		return errResult("browser_act needs a SystemOne model, and none is available for this agent. Use browser_click and browser_type instead."), nil
	}
	if dyn.Truthy(c.args["url"]) {
		if refusal, ok := c.checkURL(ctx, c.args["url"]); !ok {
			return refusal, nil
		}
	}
	provider, backend, err := c.browser(ctx)
	if err != nil {
		return nil, err
	}
	if provider == nil {
		return errResult("Browser controller not available"), nil
	}
	if backend == "local-computer" {
		return dyn.Ordered{{Key: "error", Value: "browser_act needs the cloud computer browser. Use browser_navigate and the desktop tools on this computer."}, {Key: "backend", Value: backend}}, nil
	}
	url := ""
	if dyn.Truthy(c.args["url"]) {
		url = dyn.String(c.args["url"])
	}
	result, err := runBrowserAct(ctx, browserActRun{provider: provider, systemOne: s1, goal: goal, url: url, run: c.run, stepID: c.stepID, now: c.b.d.Now})
	if err != nil {
		return nil, err
	}
	return append(result, dyn.KV{Key: "backend", Value: backend}), nil
}

func credentialFill(ctx context.Context, c *call) (any, error) {
	if c.b.d.Credentials == nil {
		return errResult("Credential broker is unavailable."), nil
	}
	return c.b.d.Credentials.FillBrowser(ctx, c.run.UserID, c.run.AgentID, c.args, c.run.RunID)
}

func credentialSubmit(ctx context.Context, c *call) (any, error) {
	if c.b.d.Credentials == nil {
		return errResult("Credential broker is unavailable."), nil
	}
	return c.b.d.Credentials.SubmitProtected(ctx, c.run.UserID, c.run.AgentID, c.args["protected_fill_id"], c.run.RunID)
}

func credentialCancel(ctx context.Context, c *call) (any, error) {
	if c.b.d.Credentials == nil {
		return errResult("Credential broker is unavailable."), nil
	}
	return c.b.d.Credentials.CancelProtected(ctx, c.run.UserID, c.run.AgentID, c.args["protected_fill_id"], c.run.RunID)
}

func credentialHTTP(ctx context.Context, c *call) (any, error) {
	if c.b.d.Credentials == nil {
		return errResult("Credential broker is unavailable."), nil
	}
	return c.b.d.Credentials.HTTPRequest(ctx, c.run.UserID, c.run.AgentID, c.args, c.run.RunID)
}
