package handlers

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var mcpHandlers = map[string]handler{
	"mcp_add_server":    mcpAddServer,
	"mcp_list_servers":  mcpListServers,
	"mcp_remove_server": mcpRemoveServer,
}

func mcpAddServer(ctx context.Context, c *call) (any, error) {
	m := c.b.d.MCP
	if m == nil {
		return errResult("MCP manager not available"), nil
	}
	if c.b.d.DB == nil {
		return errResult("Database is unavailable."), nil
	}
	args := orAny(c.args["args"], []any{})
	env := orAny(c.args["env"], dyn.Map{})
	config := dyn.Stringify(dyn.Ordered{{Key: "args", Value: args}, {Key: "env", Value: env}})
	autoStart := c.args["auto_start"] != false
	enabled := 0
	if autoStart {
		enabled = 1
	}
	res, err := c.b.d.DB.W.ExecContext(ctx,
		`INSERT INTO mcp_servers (user_id, agent_id, name, command, config, enabled) VALUES (?, ?, ?, ?, ?, ?)`,
		c.run.UserID, nilIfEmpty(c.run.AgentID), sqlArg(c.args["name"]), sqlArg(c.args["command"]), config, enabled)
	if err != nil {
		return failure(ctx, err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		return failure(ctx, err)
	}
	tools := []any{}
	if autoStart {
		started, err := m.Start(ctx, id, str(c.args["command"]), str(c.args["name"]), c.run.UserID, c.run.AgentID)
		if err != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			return dyn.Ordered{{Key: "registered", Value: true}, {Key: "id", Value: id}, {Key: "started", Value: false}, {Key: "error", Value: "Registered but failed to start: " + err.Error()}}, nil
		}
		if started != nil {
			tools = started
		}
	}
	names := make([]any, len(tools))
	for i, t := range tools {
		if n := dyn.Get(t, "name"); dyn.Truthy(n) {
			names[i] = n
		} else {
			names[i] = t
		}
	}
	return dyn.Ordered{
		{Key: "registered", Value: true}, {Key: "id", Value: id}, {Key: "name", Value: c.args["name"]},
		{Key: "started", Value: autoStart}, {Key: "toolCount", Value: len(tools)}, {Key: "tools", Value: names},
	}, nil
}

func mcpListServers(ctx context.Context, c *call) (any, error) {
	if c.b.d.DB == nil {
		return nil, errors.New("Database is unavailable.")
	}
	rows, err := c.b.d.DB.R.QueryContext(ctx, `SELECT id, name, command, config, enabled FROM mcp_servers WHERE user_id = ? AND agent_id = ? ORDER BY name ASC`, c.run.UserID, nilIfEmpty(c.run.AgentID))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	live := map[int64]dyn.Map{}
	if c.b.d.MCP != nil {
		live = c.b.d.MCP.Status(c.run.UserID, c.run.AgentID)
	}
	servers := []any{}
	for rows.Next() {
		var id int64
		var name, command string
		var config sql.NullString
		var enabled int64
		if err := rows.Scan(&id, &name, &command, &config, &enabled); err != nil {
			return nil, err
		}
		cfg := "{}"
		if config.Valid && config.String != "" {
			cfg = config.String
		}
		parsed, ok := dyn.Parse(cfg)
		if !ok {
			return nil, fmt.Errorf("Unexpected token in JSON at position 0")
		}
		argList := orAny(dyn.Get(parsed, "args"), []any{})
		st := live[id]
		servers = append(servers, dyn.Ordered{
			{Key: "id", Value: id},
			{Key: "name", Value: name},
			{Key: "command", Value: command},
			{Key: "args", Value: argList},
			{Key: "enabled", Value: enabled != 0},
			{Key: "status", Value: orAny(st["status"], "stopped")},
			{Key: "toolCount", Value: orAny(st["toolCount"], 0)},
			{Key: "error", Value: orAny(st["error"], nil)},
			{Key: "consecutiveFails", Value: orAny(st["consecutiveFails"], 0)},
			{Key: "nextRetryAt", Value: orAny(st["nextRetryAt"], nil)},
		})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return dyn.Map{"servers": servers}, nil
}

func mcpRemoveServer(ctx context.Context, c *call) (any, error) {
	if c.b.d.DB == nil {
		return nil, errors.New("Database is unavailable.")
	}
	var id int64
	var name string
	err := c.b.d.DB.R.QueryRowContext(ctx, `SELECT id, name FROM mcp_servers WHERE id = ? AND user_id = ?`, sqlArg(c.args["server_id"]), c.run.UserID).Scan(&id, &name)
	if errors.Is(err, sql.ErrNoRows) {
		return errResult("No MCP server with id " + jsText(c.args["server_id"]) + " found"), nil
	}
	if err != nil {
		return nil, err
	}
	if c.b.d.MCP != nil {
		c.b.d.MCP.Stop(id)
	}
	if _, err := c.b.d.DB.W.ExecContext(ctx, `DELETE FROM mcp_servers WHERE id = ?`, id); err != nil {
		return nil, err
	}
	return dyn.Ordered{{Key: "removed", Value: true}, {Key: "id", Value: id}, {Key: "name", Value: name}}, nil
}
