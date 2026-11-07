---
name: Attached Repos
description: Assigns a role to every repository attached to the session and sets the rules for working across them.
---

# Attached Repos

A session can hold more than 1 repository. One is the project: the code
the task changes. Another can be a workcenter: a repository that supplies
tools, skills, and gates for one kind of work, such as PCB design. This
skill decides which is which and how the agent moves between them.

## Install

Copy this folder to `.claude/skills/attached-repos/`. Claude Code loads
skills from every attached repository, so the skill is active whether
this repository is the only one in the session or one of several.

## When it runs

Run the steps at the start of any session that holds more than 1
repository, and again when a repository is added mid-session. Run them
before the first edit.

## Inputs

1. The working directory. In a cloud session with several repositories
   it sits above the clones.
2. `$CLAUDE_ADDITIONAL_DIRECTORIES`, when set. Each entry is a directory
   the session can read and edit.
3. `WORKCENTER.md` at a repository root. Its presence marks a
   workcenter. Its contents list the tools, skills, gates, and paths the
   workcenter provides.
4. A `ROUTING.md` inside a directory whose name ends in `agent-kit`
   (`agent-kit/`, `ee-agent-kit/`) at a repository root. Its presence
   marks a project governed by this kit.

## Steps

1. List the repositories. Take the working directory and every entry in
   `$CLAUDE_ADDITIONAL_DIRECTORIES`. A directory that holds `.git` is a
   repository. A directory that does not: list its subdirectories that
   hold `.git`. Record the path and current branch of each.
2. Assign 1 role per repository:
   - `workcenter`: `WORKCENTER.md` exists at the root.
   - `project`: every other repository. If more than 1 repository is a
     project, the task names the target. If the task does not, ask
     before the first edit.
3. Read, in this order: the project's kit `ROUTING.md` when present, then the project's `AGENTS.md` or `CLAUDE.md`, then each
   workcenter's `WORKCENTER.md`. The workcenter's skills are already
   loaded; `WORKCENTER.md` says which skill fits which step.
4. Apply the rules below for the rest of the session.
5. Report the roles in the first message after setup, 1 line per
   repository: path, role, branch. Repeat the line for a repository
   whose role changes.

## Rules

- **The project is the only write target.** Edits, generated files,
  reports, and commits land in the project repository.
- **A workcenter is read-only.** The agent runs its tools, follows its
  skills, and reads its docs. It does not edit, commit to, or branch a
  workcenter unless the task is about the workcenter itself. Then the
  workcenter is the project for that task and the rule above applies
  to it.
- **Workcenter gates bind project files.** `WORKCENTER.md` names gates,
  such as "DRC passes before Gerber export". The agent treats each one
  as a `VERIFICATION.md` gate of the project. A project `AGENTS.md` can
  add gates. It cannot remove a workcenter gate.
- **Precedence inside the project is unchanged.** The project's
  `AGENTS.md` governs its code and `TONE.md` governs the agent's words.
  Where a workcenter rule and a project rule conflict on a project
  file, the project rule wins, except for gates.
- **Tool state stays out of the project.** Caches, logs, and scratch
  output of workcenter tools go to the scratchpad or to a path
  `WORKCENTER.md` names. `.gitignore` entries the workcenter requires
  land in the project in the first commit that uses the tool.
- **1 branch per repository.** A task that changes 2 repositories gets
  2 branches and 2 pull requests, each citing the other.
- **No workcenter attached, tools present.** An environment can hold a
  workcenter installed by its setup script. Check
  `/opt/workcenters/*/WORKCENTER.md`. Treat each as a workcenter with no
  repository: read its manifest, run its tools, write nothing there.

## Checks

- Every repository has exactly 1 role before the first edit.
- The roles report names the branch of every repository.
- No commit lands in a workcenter during a project task.
- Every gate in a workcenter's `WORKCENTER.md` appears in the project's
  verification run, or the report says it did not run and why.
