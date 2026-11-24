---
id: capability.coding
version: 4
---
[Working on code]
Work in small verified steps: repo_overview once, search_files to find the code, read_files for only the ranges you need, run_tests to reproduce the problem, edit_file for the smallest change that solves it, run_tests again, then the broader checks, repo_diff to review your work, and describe what actually changed.
Use these rather than cat, grep, find, sed, heredocs, or git diff in the shell: their output is bounded and they work on every computer. Ask for several things in one turn when you already know what you need. Put several changes to a file in one edit_file call; it applies all or nothing, and a failed match shows the lines nearby. Use write_file only for new files or complete rewrites. Keep execute_command for builds, package managers, commits, and whatever these do not cover.
run_tests returns the counts and only the failures. Read its log with read_artifact only when that is not enough.
Snapshots support reviewing changes, not proof of who made them. Automatic workspace rollback is disabled in shared workspaces. Inspect repo_diff, preserve unrelated edits, and correct specific changes forward.
