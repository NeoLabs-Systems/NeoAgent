package skills

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"github.com/NeoLabs-Systems/neoagent/internal/jsrules"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

const (
	ownerGlobal = "global"
	ownerUser   = "user"
	ownerLegacy = "legacy"
)

// Refusal is an answer the API shows as `{error: message}` (status chosen by
// the route), as opposed to a failure of the server itself.
type Refusal struct{ Message string }

func (r *Refusal) Error() string { return r.Message }

func asRefusal(err error) (*Refusal, bool) {
	var r *Refusal
	ok := errors.As(err, &r)
	return r, ok
}

func refuse(format string, args ...any) error {
	return &Refusal{Message: fmt.Sprintf(format, args...)}
}

// Skill is a loaded skill: a SKILL.md and where it came from.
type Skill struct {
	Key          string
	Name         string
	Description  string
	Metadata     Meta
	Instructions string
	FilePath     string
	Dir          string
	OwnerType    string
	UserID       int64 // meaningful for user and legacy skills
	ReadOnly     bool
}

// Enabled is false only for a skill whose metadata says enabled: false.
func (s Skill) Enabled() bool { return s.Metadata.Value("enabled") != false }

type override struct {
	enabled *bool
	hidden  bool
}

// CommandRunner executes a skill's command template inside the user's
// computer.
type CommandRunner interface {
	ExecuteCommand(ctx context.Context, userID int64, command string) (workspace.Obj, error)
}

// RunnerConfig wires a Runner.
type RunnerConfig struct {
	DB *dbx.DB
	// Dir is the skills folder (agent-data/skills): shared skills live in it,
	// user skills under users/<id>/<name>.
	Dir      string
	Log      *slog.Logger
	Commands CommandRunner // optional; skills with a command need it
	// Libraries are the skill libraries shipped with NeoAgent; nil uses the
	// ones built into the binary (internal/skills/libraries).
	Libraries fs.FS
}

// Runner holds every skill in memory and keeps files and database in step, as
// the Node SkillRunner did.
type Runner struct {
	db        *dbx.DB
	dir       string
	usersDir  string
	log       *slog.Logger
	commands  CommandRunner
	libraries fs.FS

	catalogMu sync.Mutex
	catalog   []Builtin

	mu        sync.RWMutex
	skills    map[string]*Skill
	order     []string
	overrides map[int64]map[string]override
}

// NewRunner builds a runner; call Load before use.
func NewRunner(cfg RunnerConfig) *Runner {
	dir := filepath.Clean(cfg.Dir)
	libraries := cfg.Libraries
	if libraries == nil {
		libraries = builtinLibraries()
	}
	return &Runner{
		db: cfg.DB, dir: dir, usersDir: filepath.Join(dir, "users"), log: cfg.Log, commands: cfg.Commands, libraries: libraries,
		skills: map[string]*Skill{}, overrides: map[int64]map[string]override{},
	}
}

func skillKey(ownerType string, userID int64, name string) string {
	if ownerType == ownerGlobal {
		return ownerType + ":global:" + name
	}
	return ownerType + ":" + strconv.FormatInt(userID, 10) + ":" + name
}

// Load reads the shared skills folder and the user skills stored in the
// database. Skills the removed built-in store installed are deleted.
func (r *Runner) Load(ctx context.Context) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.skills = map[string]*Skill{}
	r.order = nil
	r.overrides = map[int64]map[string]override{}

	rows, err := r.db.R.QueryContext(ctx, `SELECT user_id, skill_name, enabled, hidden FROM user_skill_overrides`)
	if err != nil {
		return err
	}
	for rows.Next() {
		var userID int64
		var name string
		var enabled sql.NullInt64
		var hidden int64
		if err := rows.Scan(&userID, &name, &enabled, &hidden); err != nil {
			rows.Close()
			return err
		}
		o := override{hidden: hidden == 1}
		if enabled.Valid {
			on := enabled.Int64 != 0
			o.enabled = &on
		}
		r.overridesFor(userID)[name] = o
	}
	if err := rows.Close(); err != nil {
		return err
	}

	type stored struct {
		userID   int64
		filePath string
		enabled  bool
		metadata string
	}
	var dbSkills []stored
	dbRows, err := r.db.R.QueryContext(ctx, `SELECT user_id, file_path, enabled, metadata FROM skills ORDER BY id`)
	if err != nil {
		return err
	}
	dbPaths := map[string]bool{}
	for dbRows.Next() {
		var s stored
		var enabled sql.NullInt64
		var meta sql.NullString
		if err := dbRows.Scan(&s.userID, &s.filePath, &enabled, &meta); err != nil {
			dbRows.Close()
			return err
		}
		s.enabled = !enabled.Valid || enabled.Int64 != 0
		s.metadata = meta.String
		dbSkills = append(dbSkills, s)
		dbPaths[absPath(s.filePath)] = true
	}
	if err := dbRows.Close(); err != nil {
		return err
	}

	if info, err := os.Stat(r.dir); err == nil && info.IsDir() {
		r.loadDir(r.dir, dbPaths, map[string]bool{})
	}
	for _, s := range dbSkills {
		if _, err := os.Stat(s.filePath); err != nil {
			continue
		}
		owner := ownerLegacy
		if s.userID > 0 {
			owner = ownerUser
		}
		enabled := s.enabled
		r.loadFile(s.filePath, owner, s.userID, &enabled, decodeMeta(s.metadata))
	}
	return nil
}

func absPath(p string) string {
	if abs, err := filepath.Abs(p); err == nil {
		return abs
	}
	return filepath.Clean(p)
}

func (r *Runner) loadDir(dir string, dbPaths, loaded map[string]bool) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, entry := range entries {
		full := filepath.Join(dir, entry.Name())
		if absPath(full) == absPath(r.usersDir) {
			continue
		}
		if entry.IsDir() {
			file := filepath.Join(full, "SKILL.md")
			if _, err := os.Stat(file); err == nil && !dbPaths[absPath(file)] {
				if r.retired(file) {
					os.RemoveAll(full)
					continue
				}
				r.loadFile(file, ownerGlobal, 0, nil, nil)
				loaded[absPath(file)] = true
			}
			r.loadDir(full, dbPaths, loaded)
		} else if strings.HasSuffix(entry.Name(), ".md") && !loaded[absPath(full)] && !dbPaths[absPath(full)] {
			if r.retired(full) {
				os.Remove(full)
				continue
			}
			r.loadFile(full, ownerGlobal, 0, nil, nil)
			loaded[absPath(full)] = true
		}
	}
}

func (r *Runner) retired(file string) bool {
	data, err := os.ReadFile(file)
	return err == nil && isRetiredStoreSkill(string(data))
}

// loadFile reads one skill file into memory. Unreadable or nameless files are
// skipped, with a note in the log.
func (r *Runner) loadFile(file, owner string, userID int64, enabled *bool, extra Meta) {
	data, err := os.ReadFile(file)
	if err != nil {
		r.log.Error("failed to load skill", "path", file, "error", err)
		return
	}
	parsed, ok := parseSkillFile(string(data))
	if !ok {
		return
	}
	meta := parsed.Metadata.Merge(extra)
	if enabled != nil {
		meta = meta.With("enabled", *enabled)
	}
	if owner == ownerGlobal {
		userID = 0
	}
	skill := &Skill{
		Key: skillKey(owner, userID, parsed.Name), Name: parsed.Name, Description: parsed.Description,
		Metadata: meta, Instructions: parsed.Instructions, FilePath: file, Dir: filepath.Dir(file),
		OwnerType: owner, UserID: userID, ReadOnly: owner != ownerUser,
	}
	if _, exists := r.skills[skill.Key]; !exists {
		r.order = append(r.order, skill.Key)
	}
	r.skills[skill.Key] = skill
}

func (r *Runner) overridesFor(userID int64) map[string]override {
	m := r.overrides[userID]
	if m == nil {
		m = map[string]override{}
		r.overrides[userID] = m
	}
	return m
}

func (r *Runner) all() []*Skill {
	out := make([]*Skill, 0, len(r.order))
	for _, key := range r.order {
		out = append(out, r.skills[key])
	}
	return out
}

// visible is what a user sees: their own skills, and the shared ones they
// have not hidden or replaced, with their own on/off choice applied.
func (r *Runner) visible(userID int64) []Skill {
	if userID <= 0 {
		out := make([]Skill, 0, len(r.order))
		for _, s := range r.all() {
			out = append(out, *s)
		}
		return out
	}
	owned := map[string]bool{}
	for _, s := range r.all() {
		if s.OwnerType == ownerUser && s.UserID == userID {
			owned[s.Name] = true
		}
	}
	ov := r.overrides[userID]
	var out []Skill
	for _, s := range r.all() {
		if s.OwnerType == ownerUser {
			if s.UserID == userID {
				out = append(out, *s)
			}
			continue
		}
		if owned[s.Name] || ov[s.Name].hidden {
			continue
		}
		copy := *s
		if enabled := ov[s.Name].enabled; enabled != nil {
			copy.Metadata = s.Metadata.With("enabled", *enabled)
		}
		out = append(out, copy)
	}
	return out
}

// GetAll lists the skills a user sees.
func (r *Runner) GetAll(userID int64) []Skill {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.visible(userID)
}

// GetSkill finds a skill by name: the user's own first, then a shared one.
func (r *Runner) GetSkill(name string, userID int64) (Skill, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.getSkill(name, userID)
}

func (r *Runner) getSkill(name string, userID int64) (Skill, bool) {
	wanted := NormalizeName(name)
	if wanted == "" {
		return Skill{}, false
	}
	if s, ok := r.skills[skillKey(ownerUser, userID, wanted)]; ok {
		return *s, true
	}
	for _, s := range r.visible(userID) {
		if s.Name == wanted {
			return s, true
		}
	}
	return Skill{}, false
}

func (r *Runner) canEdit(s Skill, userID int64) bool {
	return s.OwnerType == ownerUser && s.UserID == userID
}

// Saved is what saving a skill answers.
type Saved struct {
	Success   bool    `json:"success"`
	Name      string  `json:"name"`
	Path      string  `json:"path"`
	VersionID *string `json:"versionId"`
}

// Create writes a new skill of the user.
func (r *Runner) Create(ctx context.Context, userID int64, name, description, instructions string, metadata Meta) (Saved, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.create(ctx, userID, name, description, instructions, metadata)
}

func (r *Runner) create(ctx context.Context, userID int64, name, description, instructions string, metadata Meta) (Saved, error) {
	if userID <= 0 {
		return Saved{}, refuse("Missing or invalid userId")
	}
	safe := NormalizeName(name)
	if safe == "" {
		return Saved{}, refuse("Skill name is required")
	}
	if _, exists := r.skills[skillKey(ownerUser, userID, safe)]; exists {
		return Saved{}, refuse("Skill '%s' already exists", safe)
	}

	skillDir := filepath.Join(r.usersDir, strconv.FormatInt(userID, 10), safe)
	if err := os.MkdirAll(skillDir, 0o700); err != nil {
		return Saved{}, err
	}
	file := filepath.Join(skillDir, "SKILL.md")
	text := buildFrontmatter(safe, description, metadata) + "\n\n" + instructions
	if err := os.WriteFile(file, []byte(text), 0o600); err != nil {
		return Saved{}, err
	}
	enabled := 1
	if metadata.Value("enabled") == false {
		enabled = 0
	}
	_, err := r.db.W.ExecContext(ctx, `INSERT INTO skills (user_id, name, description, file_path, metadata, enabled, auto_created, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, 1, datetime('now'))`, userID, safe, description, file, jsrules.JSON(metadata), enabled)
	if err != nil {
		os.Remove(file)
		if left, _ := os.ReadDir(skillDir); len(left) == 0 {
			os.Remove(skillDir)
		}
		if strings.Contains(err.Error(), "UNIQUE") {
			return Saved{}, refuse("Skill '%s' already exists", safe)
		}
		return Saved{}, err
	}
	on := enabled == 1
	r.loadFile(file, ownerUser, userID, &on, metadata)
	versionID, err := r.recordVersion(ctx, userID, safe, "validated")
	if err != nil {
		return Saved{}, err
	}
	return Saved{Success: true, Name: safe, Path: file, VersionID: versionID}, nil
}

// Edit says which parts of a skill an update changes.
type Edit struct {
	Description  *string
	Instructions *string
	Metadata     *Meta
	// SkipVersion saves without recording a version (an on/off switch).
	SkipVersion bool
}

// Update changes a skill of the user. Editing a shared skill gives the user a
// copy of their own.
func (r *Runner) Update(ctx context.Context, userID int64, name string, edit Edit) (Saved, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.update(ctx, userID, name, edit)
}

func (r *Runner) update(ctx context.Context, userID int64, name string, edit Edit) (Saved, error) {
	skill, ok := r.getSkill(name, userID)
	if !ok {
		return Saved{}, refuse("Skill '%s' not found", name)
	}
	if !r.canEdit(skill, userID) {
		return r.fork(ctx, userID, skill, edit)
	}
	description := skill.Description
	if edit.Description != nil {
		description = *edit.Description
	}
	instructions := skill.Instructions
	if edit.Instructions != nil {
		instructions = *edit.Instructions
	}
	meta := skill.Metadata.Without("name", "description")
	if edit.Metadata != nil {
		meta = *edit.Metadata
	}

	text := buildFrontmatter(skill.Name, description, meta) + "\n\n" + instructions
	if err := os.WriteFile(skill.FilePath, []byte(text), 0o600); err != nil {
		return Saved{}, err
	}
	enabled := 1
	if meta.Value("enabled") == false {
		enabled = 0
	}
	if _, err := r.db.W.ExecContext(ctx, `UPDATE skills SET description = ?, metadata = ?, enabled = ?, updated_at = datetime('now')
		WHERE user_id = ? AND name = ?`, description, jsrules.JSON(meta), enabled, userID, skill.Name); err != nil {
		return Saved{}, err
	}
	on := enabled == 1
	r.loadFile(skill.FilePath, ownerUser, userID, &on, meta)
	var versionID *string
	if !edit.SkipVersion {
		id, err := r.recordVersion(ctx, userID, skill.Name, "validated")
		if err != nil {
			return Saved{}, err
		}
		versionID = id
	}
	return Saved{Success: true, Name: skill.Name, Path: skill.FilePath, VersionID: versionID}, nil
}

// fork gives the user their own copy of a shared skill, bundled files
// included, which then takes the shared skill's place in their list.
func (r *Runner) fork(ctx context.Context, userID int64, skill Skill, edit Edit) (Saved, error) {
	description := skill.Description
	if edit.Description != nil {
		description = *edit.Description
	}
	instructions := skill.Instructions
	if edit.Instructions != nil {
		instructions = *edit.Instructions
	}
	meta := skill.Metadata.Without("name", "description")
	if edit.Metadata != nil {
		meta = *edit.Metadata
	}
	saved, err := r.create(ctx, userID, skill.Name, description, instructions, meta)
	if err != nil {
		return Saved{}, err
	}
	// Only a skill with a folder of its own carries files; a loose SKILL.md at
	// the top of the skills folder shares it with every other skill.
	if filepath.Base(skill.FilePath) == "SKILL.md" && absPath(skill.Dir) != absPath(r.dir) {
		target := filepath.Dir(saved.Path)
		entries, err := os.ReadDir(skill.Dir)
		if err != nil {
			return Saved{}, err
		}
		for _, e := range entries {
			if e.Name() == "SKILL.md" {
				continue
			}
			if err := copyTree(filepath.Join(skill.Dir, e.Name()), filepath.Join(target, e.Name())); err != nil {
				return Saved{}, err
			}
		}
	}
	return saved, nil
}

func copyTree(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(target, 0o700)
		}
		if !d.Type().IsRegular() {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(target, data, 0o600)
	})
}

// SetEnabled switches a skill on or off for a user. A shared skill is
// switched through a per-user override and its file is left alone.
func (r *Runner) SetEnabled(ctx context.Context, userID int64, name string, enabled bool) (any, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	skill, ok := r.getSkill(name, userID)
	if !ok {
		return nil, refuse("Skill '%s' not found", name)
	}
	if !r.canEdit(skill, userID) {
		if err := r.writeOverride(ctx, userID, skill.Name, func(o *override) { o.enabled = &enabled }); err != nil {
			return nil, err
		}
		return Toggled{Success: true, Name: skill.Name}, nil
	}
	meta := skill.Metadata.With("enabled", enabled)
	return r.update(ctx, userID, skill.Name, Edit{Metadata: &meta, SkipVersion: true})
}

// Toggled is what switching a shared skill answers; its file is untouched.
type Toggled struct {
	Success bool   `json:"success"`
	Name    string `json:"name"`
}

func (r *Runner) writeOverride(ctx context.Context, userID int64, name string, change func(*override)) error {
	next := r.overridesFor(userID)[name]
	change(&next)
	var enabled any
	if next.enabled != nil {
		enabled = boolInt(*next.enabled)
	}
	_, err := r.db.W.ExecContext(ctx, `INSERT INTO user_skill_overrides (user_id, skill_name, enabled, hidden, updated_at)
		VALUES (?, ?, ?, ?, datetime('now'))
		ON CONFLICT(user_id, skill_name) DO UPDATE SET
		  enabled = excluded.enabled, hidden = excluded.hidden, updated_at = excluded.updated_at`,
		userID, name, enabled, boolInt(next.hidden))
	if err != nil {
		return err
	}
	r.overridesFor(userID)[name] = next
	return nil
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// Deleted is what deleting a skill answers.
type Deleted struct {
	Success bool   `json:"success"`
	Deleted string `json:"deleted"`
}

// Delete removes a skill from a user's list. A shared skill, or one the user's
// copy was shadowing, is hidden for them only.
func (r *Runner) Delete(ctx context.Context, userID int64, name string) (Deleted, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	skill, ok := r.getSkill(name, userID)
	if !ok {
		return Deleted{}, refuse("Skill '%s' not found", name)
	}
	for _, s := range r.skills {
		if s.OwnerType != ownerUser && s.Name == skill.Name {
			if err := r.writeOverride(ctx, userID, skill.Name, func(o *override) { o.hidden = true }); err != nil {
				return Deleted{}, err
			}
			break
		}
	}
	if !r.canEdit(skill, userID) {
		return Deleted{Success: true, Deleted: skill.Name}, nil
	}

	// A user skill owns its whole folder, bundled scripts and references
	// included.
	own := filepath.Join(r.usersDir, strconv.FormatInt(userID, 10), skill.Name)
	if filepath.Base(skill.FilePath) == "SKILL.md" && absPath(filepath.Dir(skill.FilePath)) == absPath(own) {
		os.RemoveAll(filepath.Dir(skill.FilePath))
	} else {
		os.Remove(skill.FilePath)
	}

	tx, err := r.db.W.BeginTx(ctx, nil)
	if err != nil {
		return Deleted{}, err
	}
	defer tx.Rollback()
	var id int64
	err = tx.QueryRowContext(ctx, `SELECT id FROM skills WHERE user_id = ? AND name = ?`, userID, skill.Name).Scan(&id)
	if err == nil {
		skillID := strconv.FormatInt(id, 10)
		if _, err := tx.ExecContext(ctx, `DELETE FROM agent_skill_evaluations WHERE skill_version_id IN
			(SELECT id FROM agent_skill_versions WHERE skill_id = ?)`, skillID); err != nil {
			return Deleted{}, err
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM agent_skill_versions WHERE skill_id = ?`, skillID); err != nil {
			return Deleted{}, err
		}
	} else if !errors.Is(err, sql.ErrNoRows) {
		return Deleted{}, err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM skills WHERE user_id = ? AND name = ?`, userID, skill.Name); err != nil {
		return Deleted{}, err
	}
	if err := tx.Commit(); err != nil {
		return Deleted{}, err
	}
	delete(r.skills, skill.Key)
	for i, key := range r.order {
		if key == skill.Key {
			r.order = append(r.order[:i], r.order[i+1:]...)
			break
		}
	}
	return Deleted{Success: true, Deleted: skill.Name}, nil
}

// recordVersion keeps the skill file's current text as a numbered version.
func (r *Runner) recordVersion(ctx context.Context, userID int64, name, status string) (*string, error) {
	var id int64
	var file string
	var meta sql.NullString
	err := r.db.W.QueryRowContext(ctx, `SELECT id, file_path, metadata FROM skills WHERE user_id = ? AND name = ?`, userID, name).Scan(&id, &file, &meta)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	content, err := os.ReadFile(file)
	if err != nil {
		return nil, nil
	}
	skillID := strconv.FormatInt(id, 10)
	var last sql.NullInt64
	if err := r.db.W.QueryRowContext(ctx, `SELECT MAX(version) FROM agent_skill_versions WHERE skill_id = ?`, skillID).Scan(&last); err != nil {
		return nil, err
	}
	versionID, err := newUUID()
	if err != nil {
		return nil, err
	}
	metadata := meta.String
	if !meta.Valid {
		metadata = "{}"
	}
	_, err = r.db.W.ExecContext(ctx, `INSERT INTO agent_skill_versions (id, skill_id, version, name, content_md, metadata_json, validated_at, status)
		VALUES (?, ?, ?, ?, ?, ?, datetime('now'), ?)`, versionID, skillID, max(0, last.Int64)+1, name, string(content), metadata, status)
	if err != nil {
		return nil, err
	}
	return &versionID, nil
}

func newUUID() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b[:])
	return h[:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:], nil
}

// Metric is a change to a skill's usage counters.
type Metric struct{ Invocation, Success, Failure, Correction, Tokens int }

// RecordMetric adds to a skill's counters for a user and agent.
func (r *Runner) RecordMetric(ctx context.Context, userID int64, agentID *string, skillName string, m Metric) error {
	if userID <= 0 {
		return nil
	}
	var agent any
	if agentID != nil {
		agent = *agentID
	}
	_, err := r.db.W.ExecContext(ctx, `INSERT INTO skill_metrics (
		user_id, agent_id, skill_name, invocation_count, success_count,
		failure_count, correction_count, total_tokens, last_used_at
	) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
	ON CONFLICT(user_id, agent_id, skill_name) DO UPDATE SET
		invocation_count = invocation_count + excluded.invocation_count,
		success_count = success_count + excluded.success_count,
		failure_count = failure_count + excluded.failure_count,
		correction_count = correction_count + excluded.correction_count,
		total_tokens = total_tokens + excluded.total_tokens,
		last_used_at = datetime('now'),
		updated_at = datetime('now')`,
		userID, agent, skillName, m.Invocation, m.Success, m.Failure, m.Correction, m.Tokens)
	return err
}
