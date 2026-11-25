package runtime

import "context"

// Browser is the browser of a computer: the guest's Chromium, or the user's
// own desktop driven through the companion.
type Browser interface {
	Navigate(ctx context.Context, url string, options map[string]any) (*Object, error)
	Click(ctx context.Context, selector, text any, screenshot bool) (*Object, error)
	ClickPoint(ctx context.Context, x, y any, screenshot bool) (*Object, error)
	Fill(ctx context.Context, selector any, value string, options map[string]any) (*Object, error)
	TypeText(ctx context.Context, text string, options map[string]any) (*Object, error)
	PressKey(ctx context.Context, key string, screenshot bool) (*Object, error)
	Scroll(ctx context.Context, deltaX, deltaY any, screenshot bool) (*Object, error)
	Extract(ctx context.Context, selector, attribute any, all bool) (*Object, error)
	ExtractContent(ctx context.Context, options map[string]any) (*Object, error)
	Evaluate(ctx context.Context, script string) (*Object, error)
	Screenshot(ctx context.Context, options map[string]any) (*Object, error)
	ScreenshotJPEG(ctx context.Context, quality int, options map[string]any) ([]byte, error)
	Launch(ctx context.Context, options map[string]any) (*Object, error)
	Close(ctx context.Context) (*Object, error)
	FillCredential(ctx context.Context, input map[string]any) (*Object, error)
	SubmitProtectedCredential(ctx context.Context, id string) (*Object, error)
	CancelProtectedCredential(ctx context.Context, id string) (*Object, error)
	// Status is {launched, pages, headless, pageInfo}.
	Status(ctx context.Context) (*Object, error)
}

// Desktop is the screen of a computer.
type Desktop interface {
	Status(ctx context.Context) *Object
	Screenshot(ctx context.Context) (*Object, error)
	Observe(ctx context.Context) (*Object, error)
	ClickPoint(ctx context.Context, x, y, button any) (*Object, error)
	MouseMove(ctx context.Context, x, y any) (*Object, error)
	Drag(ctx context.Context, x1, y1, x2, y2, durationMs any) (*Object, error)
	Scroll(ctx context.Context, deltaX, deltaY any) (*Object, error)
	TypeText(ctx context.Context, text string, pressEnter bool) (*Object, error)
	PressKey(ctx context.Context, key string) (*Object, error)
	LaunchApp(ctx context.Context, app string) (*Object, error)
	AccessibilityTree(ctx context.Context) (*Object, error)
}

// computer is what a provider (cloud or local) runs on.
type computer interface {
	Readiness() *Object
	Status(ctx context.Context, key string) *Object
	// Alive is a running guest or a connected device; Tracked any session.
	Alive(key string) bool
	Tracked(key string) bool
	// Wake makes the computer show its screen; Prepare makes it fully usable.
	Wake(ctx context.Context, key string) error
	Prepare(ctx context.Context, key string) error
	Stop(ctx context.Context, key string)
	RequestGuest(ctx context.Context, key, method, path string, body any, o RequestOptions) (*Object, error)
	ExecuteCommand(ctx context.Context, key, command string, o ExecOptions) (*Object, error)
	KillCommand(ctx context.Context, key string, pid any, reason string) (*Object, error)
	OpenBrowser(ctx context.Context, key string) (Browser, error)
	OpenDesktop(key string) Desktop
	TouchActivity(key string)
	Shutdown()
}

// The VM backend as a computer.

// Readiness implements computer.
func (b *VMBackend) Readiness() *Object { return b.vm.Readiness() }

// Status implements computer.
func (b *VMBackend) Status(_ context.Context, key string) *Object { return b.vm.Status(key) }

// Alive implements computer.
func (b *VMBackend) Alive(key string) bool { return b.vm.Alive(key) }

// Tracked implements computer.
func (b *VMBackend) Tracked(key string) bool { return b.vm.Tracked(key) }

// Wake implements computer: the guest boots far enough to show its screen.
func (b *VMBackend) Wake(ctx context.Context, key string) error {
	_, err := b.vm.Ensure(ctx, key)
	return err
}

// Prepare implements computer: the guest agent answers.
func (b *VMBackend) Prepare(ctx context.Context, key string) error {
	_, err := b.Client(ctx, key)
	return err
}

// Stop implements computer.
func (b *VMBackend) Stop(_ context.Context, key string) { b.vm.Kill(key) }

// OpenBrowser implements computer.
func (b *VMBackend) OpenBrowser(ctx context.Context, key string) (Browser, error) {
	return b.Browser(ctx, key)
}

// OpenDesktop implements computer.
func (b *VMBackend) OpenDesktop(key string) Desktop {
	return &DesktopProvider{backend: b, userKey: key, artifacts: b.artifacts}
}

var _ computer = (*VMBackend)(nil)
