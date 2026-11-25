package handlers

import (
	"context"
)

var controlHandlers = map[string]handler{
	"task_ledger":     taskLedger,
	"search_tools":    searchTools,
	"activate_tools":  activateTools,
	"background_task": backgroundTask,
}

func (c *call) engine() (Engine, error) {
	if c.b.d.Engine == nil {
		return nil, errorf("Agent engine is unavailable.")
	}
	return c.b.d.Engine, nil
}

func taskLedger(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err != nil {
		return nil, err
	}
	return e.UpdateTaskLedger(ctx, c.run.RunID, c.args)
}

func searchTools(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err != nil {
		return errResult("search_tools failed: " + err.Error()), nil
	}
	result, err := e.SearchTools(ctx, c.run.RunID, str(c.args["query"]), c.args["limit"])
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		return errResult("search_tools failed: " + err.Error()), nil
	}
	return result, nil
}

func activateTools(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err != nil {
		return errResult("activate_tools failed: " + err.Error()), nil
	}
	result, err := e.ActivateTools(ctx, c.run.RunID, stringList(c.args["names"]))
	if err != nil {
		return errResult("activate_tools failed: " + err.Error()), nil
	}
	return result, nil
}

func backgroundTask(ctx context.Context, c *call) (any, error) {
	e, err := c.engine()
	if err != nil {
		return errResult("background_task failed: " + err.Error()), nil
	}
	result, err := e.ManageBackgroundRun(ctx, c.run.RunID, c.args)
	if err != nil {
		return errResult("background_task failed: " + err.Error()), nil
	}
	return result, nil
}
