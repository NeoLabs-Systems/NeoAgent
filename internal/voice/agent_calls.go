package voice

import (
	"context"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

// DefaultRingTimeout is how long an agent's call rings before it is missed.
const DefaultRingTimeout = 30 * time.Second

// CallResult is how a call_user request ended.
type CallResult struct {
	Status    string `json:"status"`
	Reason    string `json:"reason,omitempty"`
	Message   string `json:"message,omitempty"`
	CallID    string `json:"callId,omitempty"`
	SessionID string `json:"sessionId,omitempty"`
}

// CallRequest asks the owner's apps to ring.
type CallRequest struct {
	UserID  int64
	AgentID string
	// RunID and ConversationID name the run that places the call.
	RunID          string
	ConversationID string
	// OpeningMessage is what the live model opens the call with, in its own words.
	OpeningMessage string
}

// AcceptResult answers a client accepting a call.
type AcceptResult struct {
	Accepted  bool
	Status    string
	SessionID string
}

// DeclineResult answers a client declining a call.
type DeclineResult struct {
	Declined bool
	Status   string
}

type invitation struct {
	callID         string
	userID         int64
	agentID        string
	agentName      string
	runID          string
	conversationID string
	openingMessage string
	expiresAt      string
	recipients     map[string]struct{}
	result         chan CallResult
	timer          *time.Timer
	settled        bool
}

// Coordinator rings the owner's apps when an agent run places a call, and
// turns the first answer into a live voice call. Only one call rings per
// account, and none while the account is on a call.
type Coordinator struct {
	rt      Realtime
	manager *Manager
	agents  AgentDirectory
	log     *slog.Logger
	ring    time.Duration

	mu            sync.Mutex
	pendingByID   map[string]*invitation
	pendingByUser map[int64]string
	shuttingDown  bool
}

// NewCoordinator builds the coordinator and registers it with the manager so
// it hears when a call it placed ends.
func NewCoordinator(rt Realtime, manager *Manager, agents AgentDirectory, log *slog.Logger) *Coordinator {
	if log == nil {
		log = slog.Default()
	}
	c := &Coordinator{
		rt: rt, manager: manager, agents: agents, log: log, ring: DefaultRingTimeout,
		pendingByID: map[string]*invitation{}, pendingByUser: map[int64]string{},
	}
	manager.SetCallNotifier(c)
	return c
}

func userRoomEvent(callID, reason string) map[string]any {
	return map[string]any{"callId": callID, "reason": reason}
}

func (c *Coordinator) incomingPayload(inv *invitation) map[string]any {
	return map[string]any{"callId": inv.callID, "agentId": nullableString(inv.agentID), "agentName": inv.agentName, "expiresAt": inv.expiresAt}
}

func nullableString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// CallUser rings the owner's connected apps and waits for the outcome:
// accepted, declined, missed, busy or unavailable. ctx cancels the ringing.
func (c *Coordinator) CallUser(ctx context.Context, req CallRequest) CallResult {
	content := livevoice.TrimJS(req.OpeningMessage)
	if content == "" {
		return CallResult{Status: "unavailable", Reason: "opening_message is required"}
	}
	c.mu.Lock()
	shutting := c.shuttingDown
	_, ringing := c.pendingByUser[req.UserID]
	c.mu.Unlock()
	if shutting || ctx.Err() != nil {
		return CallResult{Status: "cancelled"}
	}
	if ringing || c.manager.HasActiveSessionForUser(req.UserID) {
		return CallResult{Status: "busy"}
	}
	sockets := c.rt.UserSocketIDs(ctx, req.UserID)
	if len(sockets) == 0 {
		return CallResult{
			Status:  "unavailable",
			Reason:  "no_connected_app",
			Message: "The call_user tool is available, but the app is not currently connected to receive the call.",
		}
	}
	agentID, agentName := c.agents.Describe(ctx, req.UserID, req.AgentID)
	if agentID == "" {
		agentID = req.AgentID
	}
	if strings.TrimSpace(agentName) == "" {
		agentName = "NeoAgent"
	}
	inv := &invitation{
		callID: newRunID(), userID: req.UserID, agentID: agentID, agentName: strings.TrimSpace(agentName),
		runID: strings.TrimSpace(req.RunID), conversationID: strings.TrimSpace(req.ConversationID),
		openingMessage: content, expiresAt: time.Now().Add(c.ring).UTC().Format("2006-01-02T15:04:05.000Z"),
		recipients: map[string]struct{}{}, result: make(chan CallResult, 1),
	}
	for _, id := range sockets {
		inv.recipients[id] = struct{}{}
	}
	c.mu.Lock()
	if _, taken := c.pendingByUser[req.UserID]; taken {
		c.mu.Unlock()
		return CallResult{Status: "busy"}
	}
	c.pendingByID[inv.callID] = inv
	c.pendingByUser[req.UserID] = inv.callID
	inv.timer = time.AfterFunc(c.ring, func() { c.finish(inv, "missed") })
	c.mu.Unlock()
	c.log.Info("Ringing connected apps", "count", len(sockets))
	c.rt.EmitToUser(req.UserID, "voice:incoming_call", c.incomingPayload(inv))

	select {
	case result := <-inv.result:
		return result
	case <-ctx.Done():
		c.finish(inv, "cancelled")
		return <-inv.result
	}
}

// OfferPendingCall rings an app that connected while a call is ringing. It
// reports whether there was one.
func (c *Coordinator) OfferPendingCall(socketID string, userID int64) bool {
	c.mu.Lock()
	inv := c.pendingForUser(userID)
	if inv == nil || socketID == "" {
		c.mu.Unlock()
		return false
	}
	inv.recipients[socketID] = struct{}{}
	payload := c.incomingPayload(inv)
	c.mu.Unlock()
	c.rt.EmitToSocket(socketID, "voice:incoming_call", payload)
	return true
}

// Accept turns a ringing call into a live voice call on the accepting socket.
// The caller adds the returned session to the socket's own sessions so a
// disconnect detaches it.
func (c *Coordinator) Accept(ctx context.Context, callID string, userID int64, socketID string) AcceptResult {
	c.mu.Lock()
	inv := c.ownedInvitation(callID, userID)
	if inv == nil || inv.settled {
		c.mu.Unlock()
		return AcceptResult{Status: "unavailable"}
	}
	c.mu.Unlock()
	if c.manager.HasActiveSessionForUser(userID) {
		c.finish(inv, "busy")
		return AcceptResult{Status: "busy"}
	}
	c.mu.Lock()
	if inv.settled {
		c.mu.Unlock()
		return AcceptResult{Status: "unavailable"}
	}
	inv.settled = true
	inv.recipients[socketID] = struct{}{}
	c.remove(inv)
	c.mu.Unlock()
	c.rt.EmitToUserExcept(userID, socketID, "voice:call_cancelled", userRoomEvent(inv.callID, "answered_elsewhere"))

	sink := livevoice.SinkFunc(func(event string, payload map[string]any) { c.rt.EmitToSocket(socketID, event, payload) })
	call, err := c.manager.OpenFlutterSession(ctx, OpenOptions{
		UserID: userID, AgentID: inv.agentID, Sink: sink, SessionID: inv.callID,
		OriginConversation: inv.conversationID, AgentInitiated: true,
	})
	if err != nil {
		c.log.Warn("Failed to accept agent call", "error", err.Error())
		c.rt.EmitToUser(userID, "voice:call_ended", userRoomEvent(inv.callID, "unavailable"))
		inv.result <- CallResult{Status: "unavailable"}
		return AcceptResult{Status: "unavailable"}
	}
	// The live model opens the call in its own voice from the run's message.
	call.Say(inv.openingMessage)
	inv.result <- CallResult{Status: "accepted", CallID: inv.callID, SessionID: call.ID()}
	return AcceptResult{Accepted: true, Status: "accepted", SessionID: call.ID()}
}

// Decline turns a call down on one device; later asks to be called back, which
// ends the ringing on every device and which the agent hears as its outcome.
func (c *Coordinator) Decline(callID string, userID int64, socketID string, later bool) DeclineResult {
	c.mu.Lock()
	inv := c.ownedInvitation(callID, userID)
	if inv == nil || inv.settled {
		c.mu.Unlock()
		return DeclineResult{Status: "unavailable"}
	}
	if later {
		c.mu.Unlock()
		c.finish(inv, "call_later")
		return DeclineResult{Declined: true, Status: "call_later"}
	}
	delete(inv.recipients, socketID)
	none := len(inv.recipients) == 0
	c.mu.Unlock()
	c.rt.EmitToSocket(socketID, "voice:call_ended", userRoomEvent(inv.callID, "declined"))
	if none {
		c.finish(inv, "declined")
	}
	return DeclineResult{Declined: true, Status: "declined"}
}

// HandleDisconnect forgets a socket that went away while a call rang.
func (c *Coordinator) HandleDisconnect(socketID string, userID int64) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if inv := c.pendingForUser(userID); inv != nil {
		delete(inv.recipients, socketID)
	}
}

// NotifySessionClosed tells the apps that a call the agent placed has ended.
func (c *Coordinator) NotifySessionClosed(call *Call, reason string) {
	if call == nil || !call.AgentInitiated {
		return
	}
	c.rt.EmitToUser(call.UserID, "voice:call_ended", userRoomEvent(call.ID(), reason))
}

// Shutdown cancels every ringing call.
func (c *Coordinator) Shutdown() {
	c.mu.Lock()
	c.shuttingDown = true
	pending := make([]*invitation, 0, len(c.pendingByID))
	for _, inv := range c.pendingByID {
		pending = append(pending, inv)
	}
	c.mu.Unlock()
	for _, inv := range pending {
		c.finish(inv, "cancelled")
	}
}

// ownedInvitation requires c.mu.
func (c *Coordinator) ownedInvitation(callID string, userID int64) *invitation {
	inv := c.pendingByID[strings.TrimSpace(callID)]
	if inv == nil || inv.userID != userID {
		return nil
	}
	return inv
}

// pendingForUser requires c.mu.
func (c *Coordinator) pendingForUser(userID int64) *invitation {
	id, ok := c.pendingByUser[userID]
	if !ok {
		return nil
	}
	if inv := c.pendingByID[id]; inv != nil && !inv.settled {
		return inv
	}
	return nil
}

func (c *Coordinator) finish(inv *invitation, status string) {
	c.mu.Lock()
	if inv.settled {
		c.mu.Unlock()
		return
	}
	inv.settled = true
	c.remove(inv)
	c.mu.Unlock()
	c.rt.EmitToUser(inv.userID, "voice:call_ended", userRoomEvent(inv.callID, status))
	inv.result <- CallResult{Status: status, CallID: inv.callID}
}

// remove requires c.mu.
func (c *Coordinator) remove(inv *invitation) {
	if inv.timer != nil {
		inv.timer.Stop()
	}
	delete(c.pendingByID, inv.callID)
	if c.pendingByUser[inv.userID] == inv.callID {
		delete(c.pendingByUser, inv.userID)
	}
}
