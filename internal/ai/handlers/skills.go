package handlers

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

var skillHandlers = map[string]handler{
	"create_skill": createSkill,
	"list_skills":  listSkills,
	"update_skill": updateSkill,
	"delete_skill": deleteSkill,
}

const noSkillRunner = "Skill runner not available"

func createSkill(ctx context.Context, c *call) (any, error) {
	sk := c.b.d.Skills
	if sk == nil {
		return errResult(noSkillRunner), nil
	}
	return sk.Create(ctx, c.run.UserID, str(c.args["name"]), str(c.args["description"]), str(c.args["instructions"]), dyn.Obj(c.args["metadata"]))
}

func listSkills(ctx context.Context, c *call) (any, error) {
	sk := c.b.d.Skills
	if sk == nil {
		return errResult(noSkillRunner), nil
	}
	if dyn.Truthy(c.args["name"]) {
		name := dyn.String(c.args["name"])
		skill, ok := sk.Get(c.run.UserID, name)
		if !ok {
			return errResult("No skill named '" + name + "'."), nil
		}
		if dyn.Get(skill, "metadata", "enabled") == false {
			return errResult("Skill '" + dyn.Str(skill["name"]) + "' is disabled."), nil
		}
		return dyn.Ordered{
			{Key: "name", Value: skill["name"]},
			{Key: "description", Value: skill["description"]},
			{Key: "metadata", Value: skill["metadata"]},
			{Key: "instructions", Value: skill["instructions"]},
		}, nil
	}
	// Skill files live on the NeoAgent host, which the agent's tools cannot
	// read; their contents come from this tool instead.
	all := sk.All(c.run.UserID)
	if all == nil {
		all = []any{}
	}
	return dyn.Ordered{{Key: "skills", Value: all}, {Key: "count", Value: len(all)}}, nil
}

func optionalString(v any) *string {
	if v == nil {
		return nil
	}
	s := dyn.String(v)
	return &s
}

func updateSkill(ctx context.Context, c *call) (any, error) {
	sk := c.b.d.Skills
	if sk == nil {
		return errResult(noSkillRunner), nil
	}
	// The model changes only the fields it names; the rest, including the
	// learning record of a learned skill, carries over.
	metadata, hasMetadata := c.args["metadata"].(dyn.Map)
	if current, ok := sk.Get(c.run.UserID, str(c.args["name"])); ok && hasMetadata {
		merged := dyn.Map{}
		for k, v := range dyn.Obj(current["metadata"]) {
			merged[k] = v
		}
		for k, v := range metadata {
			merged[k] = v
		}
		metadata = merged
	}
	return sk.Update(ctx, c.run.UserID, str(c.args["name"]), optionalString(c.args["description"]), optionalString(c.args["instructions"]), metadata, hasMetadata)
}

func deleteSkill(ctx context.Context, c *call) (any, error) {
	sk := c.b.d.Skills
	if sk == nil {
		return errResult(noSkillRunner), nil
	}
	return sk.Delete(ctx, c.run.UserID, str(c.args["name"]))
}
