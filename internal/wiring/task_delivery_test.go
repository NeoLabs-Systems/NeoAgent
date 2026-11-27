package wiring

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type chatStub struct {
	messaging.Platform
	sent []string
}

func (c *chatStub) Connect(context.Context) error          { return nil }
func (c *chatStub) Disconnect(context.Context) error       { return nil }
func (c *chatStub) Status() string                         { return messaging.StatusConnected }
func (c *chatStub) AuthInfo() map[string]any               { return nil }
func (c *chatStub) SetAccessPolicy(messaging.AccessPolicy) {}
func (c *chatStub) SendMessage(_ context.Context, _, content string, _ messaging.SendOptions) (messaging.SendResult, error) {
	c.sent = append(c.sent, content)
	return messaging.SendResult{Success: true}, nil
}

// answeredRun is a task run as the engine ends one: the answer reached the app,
// so the delivery is marked final although the task's chat has nothing yet.
type answeredRun struct{ answer string }

func (r answeredRun) RunTask(_ context.Context, req tasks.RunRequest) (tasks.RunResult, error) {
	req.Delivery.FinalDelivered = true
	return tasks.RunResult{RunID: "run-1", Result: taskResult(agent.Result{RunID: "run-1", Content: r.answer, Status: "completed"})}, nil
}

func TestTaskAnswerReachesTheChatAndIsStored(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "tasks.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id,username,email,password) VALUES (1,'user','u@example.com','hash');
		INSERT INTO agents (id,user_id,slug,display_name,is_default) VALUES ('main',1,'main','Main',1)`); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("enc:v1:", "0123456789012345678901234567890123456789")
	if err != nil {
		t.Fatal(err)
	}
	chat := &chatStub{}
	agents := agentScopeAdapter{r: agentscope.Resolver{DB: db}}
	manager := messaging.NewManager(messaging.ManagerConfig{DB: db, Box: box, Agents: agents, DataDir: t.TempDir(),
		Factories: map[string]messaging.Factory{"discord": func(messaging.Config, messaging.Events) (messaging.Platform, error) { return chat, nil }}})
	defer manager.Stop()
	if _, err := manager.ConnectPlatform(ctx, 1, "main", "discord", map[string]any{}, true); err != nil {
		t.Fatal(err)
	}
	runtime := tasks.New(tasks.Config{DB: db, Box: box, Agents: agents, Engine: answeredRun{answer: "Good morning"},
		Messaging: &taskMessagingAdapter{mgr: manager, db: db, sender: toolMessaging{m: manager, db: db}}})
	created, err := runtime.CreateTask(ctx, 1, "main", jsv.NewObject().Set("name", "Recap").Set("triggerType", "schedule").
		Set("triggerConfig", jsv.NewObject().Set("cronExpression", "0 9 * * *")).Set("taskType", "agent_prompt").
		Set("taskConfig", jsv.NewObject().Set("prompt", "Recap").Set("notifyPlatform", "discord").Set("notifyTo", "42")).Set("enabled", true))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := runtime.RunTaskNow(ctx, int64(jsv.Number(created.Val("id"))), 1); err != nil {
		t.Fatal(err)
	}
	runtime.Wait()

	if len(chat.sent) != 1 || chat.sent[0] != "Good morning" {
		t.Fatalf("sent %q", chat.sent)
	}
	var stored, run string
	if err := db.R.QueryRow(`SELECT content, run_id FROM messages WHERE platform='discord' AND platform_chat_id='42'`).Scan(&stored, &run); err != nil {
		t.Fatal(err)
	}
	if stored != "Good morning" || run != "run-1" {
		t.Fatalf("stored %q for run %q", stored, run)
	}
}
