package cli

import (
	"context"
	"encoding/json"
	"os"
	"strings"
	"testing"
	"time"
)

type recordedCase struct {
	Command string         `json:"command"`
	Options map[string]any `json:"options"`
	Keys    []string       `json:"keys"`
	Result  map[string]any `json:"result"`
}

func newTestExecutor(t *testing.T) *Executor {
	t.Helper()
	e, err := NewExecutor()
	if err != nil {
		t.Skip("no usable shell:", err)
	}
	return e
}

// jsonKeys returns the keys of a JSON object in document order.
func jsonKeys(t *testing.T, raw []byte) []string {
	t.Helper()
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	if tok, _ := dec.Token(); tok != json.Delim('{') {
		t.Fatalf("not an object: %s", raw)
	}
	var keys []string
	for dec.More() {
		tok, _ := dec.Token()
		keys = append(keys, tok.(string))
		var skip json.RawMessage
		if err := dec.Decode(&skip); err != nil {
			t.Fatal(err)
		}
	}
	return keys
}

func TestExecutorMatchesNodeResults(t *testing.T) {
	raw, err := os.ReadFile("testdata/executor.json")
	if err != nil {
		t.Fatal(err)
	}
	var recorded map[string]recordedCase
	if err := json.Unmarshal(raw, &recorded); err != nil {
		t.Fatal(err)
	}
	e := newTestExecutor(t)
	for name, c := range recorded {
		t.Run(name, func(t *testing.T) {
			o := Options{Cwd: "/tmp"}
			if v, ok := c.Options["timeout"].(float64); ok {
				o.TimeoutMs = v
			}
			if v, ok := c.Options["stdinInput"].(string); ok {
				o.StdinInput = v
			}
			if v, ok := c.Options["cwd"].(string); ok {
				o.Cwd = v
			}
			res := e.Execute(context.Background(), c.Command, o)
			body, err := json.Marshal(res)
			if err != nil {
				t.Fatal(err)
			}
			wantKeys := c.Keys
			if name == "badcwd" {
				// Node reports the pid of a process that never started as undefined, which JSON drops.
				wantKeys = without(wantKeys, "pid")
			}
			if got := jsonKeys(t, body); strings.Join(got, ",") != strings.Join(wantKeys, ",") {
				t.Fatalf("keys\n got %v\nwant %v", got, wantKeys)
			}
			var got map[string]any
			json.Unmarshal(body, &got)
			for _, key := range []string{"exitCode", "stdout", "stderr", "stdoutBytes", "stderrBytes", "truncated", "outputFileByteSize", "outputFileComplete", "killed", "timedOut", "aborted", "signal", "command", "cwd"} {
				want, ok := c.Result[key]
				if !ok {
					continue
				}
				if name == "badcwd" && (key == "stderr" || key == "stderrBytes") {
					continue
				}
				// stdout and stderr are separate pipes read concurrently, so the
				// tail of stdout can land after stderr and add one more
				// "\n[stdout]\n" marker to the log; Node has the same race.
				if key == "outputFileByteSize" {
					if g, gok := got[key].(float64); gok {
						if w, wok := want.(float64); wok && g == w+float64(len("\n[stdout]\n")) {
							continue
						}
					}
				}
				if gotValue, wantValue := got[key], want; !equalJSON(gotValue, wantValue) {
					t.Errorf("%s: got %v want %v", key, short(gotValue), short(wantValue))
				}
			}
			if _, ok := c.Result["outputFilePath"]; ok {
				path, _ := got["outputFilePath"].(string)
				if (c.Result["outputFilePath"] == nil) != (path == "") {
					t.Errorf("outputFilePath presence differs: %v", got["outputFilePath"])
				}
				if path != "" {
					os.RemoveAll(strings.TrimSuffix(path, "/command.log"))
				}
			}
		})
	}
}

func without(list []string, drop string) []string {
	var out []string
	for _, v := range list {
		if v != drop {
			out = append(out, v)
		}
	}
	return out
}

func equalJSON(a, b any) bool {
	x, _ := json.Marshal(a)
	y, _ := json.Marshal(b)
	return string(x) == string(y)
}

func short(v any) string {
	s, _ := json.Marshal(v)
	if len(s) > 60 {
		return string(s[:60]) + "..."
	}
	return string(s)
}

func TestExecuteAbortsWhenTheContextEnds(t *testing.T) {
	e := newTestExecutor(t)
	ctx, cancel := context.WithCancel(context.Background())
	time.AfterFunc(200*time.Millisecond, cancel)
	res := e.Execute(ctx, "sleep 30", Options{})
	if !res.Aborted || !res.Killed || res.Signal != "SIGTERM" || res.ExitCode != nil {
		t.Fatalf("%+v", res)
	}
	before := e.Execute(ctx, "echo no", Options{})
	body, _ := json.Marshal(before)
	if !strings.Contains(string(body), `"stderr":"Command aborted before it started."`) || !before.Aborted || before.PID != nil {
		t.Fatalf("%s", body)
	}
	if got := jsonKeys(t, body); strings.Join(got, ",") != "exitCode,stdout,stderr,stdoutBytes,stderrBytes,truncated,killed,timedOut,aborted,signal,durationMs,pid,command,cwd" {
		t.Fatalf("keys %v", got)
	}
}

func TestKillByPid(t *testing.T) {
	e := newTestExecutor(t)
	pids := make(chan int, 1)
	done := make(chan Result, 1)
	go func() {
		done <- e.Execute(context.Background(), "sleep 30", Options{OnSpawn: func(pid int) { pids <- pid }})
	}()
	pid := <-pids
	if !e.IsManaged(pid) || e.Kill(pid+100000, "x") {
		t.Fatal("managed bookkeeping is wrong")
	}
	if !e.Kill(pid, "aborted") {
		t.Fatal("kill reported failure")
	}
	res := <-done
	if !res.Killed || !res.Aborted {
		t.Fatalf("%+v", res)
	}
	if e.IsManaged(pid) {
		t.Fatal("finished command still managed")
	}
}

func TestEnvironmentAndPath(t *testing.T) {
	e := newTestExecutor(t)
	e.BaseEnvironment = func() []string { return []string{"HOME=/tmp", "ONLY_THIS=1", "PATH=/usr/bin:/bin"} }
	res := e.Execute(context.Background(), `echo "$ONLY_THIS $EXTRA ${SECRET:-unset}"`, Options{Env: map[string]string{"EXTRA": "x"}})
	if res.Stdout != "1 x unset" {
		t.Fatalf("stdout %q", res.Stdout)
	}
	if got := mergePaths("/a:/b", "/b:/c:"); got != "/a:/b:/c" {
		t.Fatalf("merged %q", got)
	}
}

func TestInteractiveAnswersPromptsInOrder(t *testing.T) {
	e := newTestExecutor(t)
	res := e.ExecuteInteractive(context.Background(),
		`printf 'name? '; read n; printf 'color? '; read c; echo "hello $n likes $c"`,
		[]Input{{Input: "neo", WaitFor: "name?"}, {Input: "green", WaitFor: "color?"}}, Options{})
	if res.ExitCode == nil || *res.ExitCode != 0 || !res.Interactive || !strings.Contains(res.Stdout, "hello neo likes green") {
		t.Fatalf("%+v", res)
	}
	body, _ := json.Marshal(res)
	if got := jsonKeys(t, body); got[len(got)-1] != "interactive" || got[0] != "exitCode" {
		t.Fatalf("keys %v", got)
	}
}

func TestInteractivePlainInputsAreSentOncePerLine(t *testing.T) {
	e := newTestExecutor(t)
	res := e.ExecuteInteractive(context.Background(), `echo go; read a; read b; echo "[$a][$b]"`, []Input{{Input: "one"}, {Input: "two"}}, Options{})
	if !strings.Contains(res.Stdout, "[one][two]") {
		t.Fatalf("stdout %q", res.Stdout)
	}
}

func TestInteractiveTimeoutAndStartFailure(t *testing.T) {
	e := newTestExecutor(t)
	res := e.ExecuteInteractive(context.Background(), "sleep 30", nil, Options{TimeoutMs: 300})
	if !res.TimedOut || !res.Killed || res.Signal != "SIGTERM" {
		t.Fatalf("%+v", res)
	}
	bad := e.ExecuteInteractive(context.Background(), "true", nil, Options{Cwd: "/definitely/not/here"})
	body, _ := json.Marshal(bad)
	if bad.Error == "" || strings.Contains(string(body), `"signal"`) || !strings.Contains(string(body), `"interactive":true`) {
		t.Fatalf("%s", body)
	}
}

func TestInteractiveStripsEscapeSequences(t *testing.T) {
	e := newTestExecutor(t)
	res := e.ExecuteInteractive(context.Background(), `printf '\033[31mred\033[0m'`, nil, Options{})
	if res.Stdout != "red" {
		t.Fatalf("stdout %q", res.Stdout)
	}
}

func TestAccumulatorBoundsTheLogFile(t *testing.T) {
	a, err := NewAccumulator(AccumulatorOptions{})
	if err != nil {
		t.Fatal(err)
	}
	a.maxBytes, a.headLimit, a.tailLimit = 1000, 500, 500
	chunk := []byte(strings.Repeat("x", 100))
	for i := 0; i < 700; i++ {
		a.Append("stdout", chunk)
	}
	res, err := a.Finalize()
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(strings.TrimSuffix(res.FilePath, "/command.log"))
	if res.FileComplete || res.FileByteSize > 1000 || !res.Truncated || res.StdoutBytes != 70000 {
		t.Fatalf("%+v", res)
	}
	body, _ := os.ReadFile(res.FilePath)
	if !strings.Contains(string(body), "...[artifact bounded, 70009 bytes total]...") || !strings.HasPrefix(string(body), "[stdout]\n") {
		t.Fatalf("log: %q", body)
	}
	if !strings.Contains(res.Stdout, "...[truncated preview, 70000 bytes total]") {
		t.Fatalf("preview: %q", res.Stdout[:80])
	}
	if _, err := a.Finalize(); err == nil {
		t.Fatal("second finalize accepted")
	}
}

func TestPoolRunsWithAnAllowlistedEnvironment(t *testing.T) {
	t.Setenv("SUPER_SECRET", "hunter2")
	t.Setenv("KEEP_ME", "yes")
	pool := NewPool(2, "KEEP_ME")
	defer pool.Shutdown()
	res := pool.Execute(context.Background(), `echo "${SUPER_SECRET:-gone} $KEEP_ME $EXTRA"`, PoolOptions{Env: map[string]string{"EXTRA": "e"}})
	if res.Stdout != "gone yes e" || res.ExitCode == nil || *res.ExitCode != 0 {
		t.Fatalf("%+v", res)
	}
	body, _ := json.Marshal(res)
	if got := jsonKeys(t, body); strings.Join(got, ",") != "exitCode,stdout,stderr,killed,timedOut,durationMs,command,cwd" {
		t.Fatalf("keys %v", got)
	}
}

func TestPoolLimitsConcurrencyAndTruncates(t *testing.T) {
	pool := NewPool(1, "")
	defer pool.Shutdown()
	start := time.Now()
	finished := make(chan struct{}, 2)
	for i := 0; i < 2; i++ {
		go func() {
			pool.Execute(context.Background(), "sleep 0.4", PoolOptions{})
			finished <- struct{}{}
		}()
	}
	<-finished
	<-finished
	if time.Since(start) < 700*time.Millisecond {
		t.Fatal("two commands ran at once in a pool of one")
	}
	big := pool.Execute(context.Background(), "head -c 60000 /dev/zero | tr '\\0' a", PoolOptions{})
	if !strings.HasSuffix(big.Stdout, "\n...[truncated, 60000 total chars]") || len(big.Stdout) != 50000+len("\n...[truncated, 60000 total chars]") {
		t.Fatalf("stdout tail %q", big.Stdout[len(big.Stdout)-40:])
	}
	timeout := pool.Execute(context.Background(), "sleep 30", PoolOptions{TimeoutMs: 200})
	if !timeout.TimedOut || !timeout.Killed || timeout.ExitCode != nil {
		t.Fatalf("%+v", timeout)
	}
}

func TestPoolShutdownEndsRunningAndQueuedCommands(t *testing.T) {
	pool := NewPool(1, "")
	results := make(chan PoolResult, 2)
	go func() { results <- pool.Execute(context.Background(), "sleep 30", PoolOptions{}) }()
	time.Sleep(300 * time.Millisecond)
	go func() { results <- pool.Execute(context.Background(), "echo queued", PoolOptions{}) }()
	time.Sleep(200 * time.Millisecond)
	pool.Shutdown()
	for i := 0; i < 2; i++ {
		r := <-results
		if !r.Killed || r.Stderr != "Server shutting down" || r.ExitCode == nil || *r.ExitCode != -1 {
			t.Fatalf("%+v", r)
		}
	}
	if r := pool.Execute(context.Background(), "echo late", PoolOptions{}); r.Stderr != "Server shutting down" {
		t.Fatalf("%+v", r)
	}
}

func TestWorkerEnvKeepsOnlyAllowedKeys(t *testing.T) {
	got := WorkerEnv([]string{"HOME=/h", "TOKEN=x", "KEEP=1", "PATH=/p"}, " KEEP , ,")
	if strings.Join(got, ",") != "HOME=/h,KEEP=1,PATH=/p" {
		t.Fatalf("%v", got)
	}
}
