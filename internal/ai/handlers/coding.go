package handlers

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace/repotools"
)

var codingHandlers = map[string]handler{
	"repo_overview": repoOverview,
	"repo_diff":     repoDiff,
	"run_tests":     runTests,
}

const noComputer = "This needs a computer to run commands on, and none is available."

func withShell(ctx context.Context, c *call, work func(repotools.Shell) (any, error)) (any, error) {
	shell := c.workspaceShell(ctx)
	if shell == nil {
		return errResult(noComputer), nil
	}
	result, err := work(shell)
	if err != nil {
		return failure(ctx, err)
	}
	return result, nil
}

func repoOverview(ctx context.Context, c *call) (any, error) {
	return withShell(ctx, c, func(shell repotools.Shell) (any, error) {
		return repotools.Overview(ctx, shell, c.args)
	})
}

// runRepositories is what the run's checkpoints recorded it changed.
func (c *call) runRepositories() []repotools.Repository {
	if c.b.d.Engine == nil || c.run.RunID == "" {
		return nil
	}
	var out []repotools.Repository
	for _, r := range c.b.d.Engine.RunRepositories(c.run.RunID) {
		repo := repotools.Repository{Root: dyn.Str(r["root"])}
		for _, p := range dyn.List(r["paths"]) {
			repo.Paths = append(repo.Paths, repotools.RepositoryPath{Path: dyn.Str(dyn.Get(p, "path")), Source: dyn.Str(dyn.Get(p, "source"))})
		}
		out = append(out, repo)
	}
	return out
}

func repoDiff(ctx context.Context, c *call) (any, error) {
	return withShell(ctx, c, func(shell repotools.Shell) (any, error) {
		return repotools.Diff(ctx, shell, c.args, c.runRepositories())
	})
}

func runTests(ctx context.Context, c *call) (any, error) {
	var logs repotools.LogStore
	if c.b.d.Artifacts != nil {
		logs = artifactLogs{a: c.b.d.Artifacts, userID: c.run.UserID}
	}
	return withShell(ctx, c, func(shell repotools.Shell) (any, error) {
		return repotools.RunTests(ctx, shell, c.args, logs, c.run.RunID, c.stepID)
	})
}

// artifactLogs keeps test logs in the artifact store.
type artifactLogs struct {
	a      Artifacts
	userID int64
}

func (l artifactLogs) SaveLog(ctx context.Context, content []byte, runID, stepID string) (string, error) {
	stored, err := l.a.CreateBuffer(ctx, l.userID, NewArtifact{
		Kind: "command-output", Backend: "computer", Extension: "log", ContentType: "text/plain; charset=utf-8",
		FilenameBase: "test-run", Content: content,
		Metadata: dyn.Map{"runId": nilIfEmpty(runID), "stepId": nilIfEmpty(stepID)},
	})
	if err != nil {
		return "", err
	}
	return stored.ArtifactID, nil
}

func (l artifactLogs) ReadLog(ctx context.Context, artifactID string, limit int64) (string, bool) {
	path, size, ok, err := l.a.StoragePath(ctx, l.userID, artifactID)
	if err != nil || !ok || size > limit {
		return "", false
	}
	return readSmallFile(path, limit)
}
