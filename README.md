# Ralph Builder

A toolkit for creating solid PRDs and running autonomous Claude Code loops.

Based on [Geoff Huntley's Ralph](https://ghuntley.com/ralph/) - fresh context each iteration, no bloat, tasks until done.

## What It Does

1. **Setup Phase**: Claude interviews you about your project, then generates a PRD with atomic tasks
2. **Execution Phase**: Bash loop runs Claude iteratively with fresh context until complete

### The Planning Interview

When you start setup, Claude walks you through:

- **Project definition** - What are you building? Who is it for?
- **Tech stack** - Language, framework, testing (Claude recommends defaults if unsure)
- **External services** - APIs, databases, credentials needed
- **Feature breakdown** - Breaking features into atomic, verifiable tasks

The output is a structured `plan.md` with tasks that Ralph can execute one at a time.

## Quick Start

```bash
# 1. Clone ralph-builder (keep this copy for updates)
git clone https://github.com/digitalsamba/ralph-builder.git

# 2. Create your project and copy ralph-builder into it
mkdir my-project && cd my-project
git init
cp -r ../ralph-builder . && rm -rf ralph-builder/.git

# 3. Start Claude Code
claude

# 4. Ask Claude to set up your project
> Help me set up this project using Ralph Builder

# 5. Claude will guide you through PRD creation and generate files

# 6. Run the loop
./ralph-builder/ralph.sh
```

## Prerequisites

### Required
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated

### Strongly Recommended
- [Context7 MCP](https://github.com/upstash/context7) for up-to-date library documentation

Without Context7, Ralph relies on training knowledge which may use outdated patterns.

## Generated Files

After setup, your project will have:

```
my-project/                       ← your project root
├── .claude/settings.json         ← tool permissions (generated)
├── .env                          ← your credentials (you create)
├── CLAUDE.md                     ← project context (generated)
├── ralph-builder/                ← this toolkit
│   ├── ralph.sh                  ← main loop script
│   ├── SETUP-GUIDE.md            ← setup instructions
│   ├── plan.md                   ← PRD with task arrays (generated)
│   ├── PROMPT.md                 ← iteration instructions (generated)
│   ├── activity.md               ← progress log (generated)
│   └── .ralph-logs/              ← execution logs
└── src/                          ← your project code
```

### File Responsibilities

| File | Purpose |
|------|---------|
| **ralph-builder/plan.md** | Full PRD: overview, goals, success criteria, `tasks` array, `backlog` array |
| **ralph-builder/PROMPT.md** | Tells Ralph what to do each iteration: read plan, do one task, verify, commit, exit |
| **ralph-builder/activity.md** | Log of what Ralph did each iteration |
| **CLAUDE.md** | Project documentation for Claude Code (tech stack, conventions, commands) |
| **.claude/settings.json** | Tool permissions based on your tech stack |

## Task Format

Tasks use boolean `passes` with verification criteria:

```json
{
  "tasks": [
    {
      "description": "Set up Express server with health endpoint",
      "verification": "curl localhost:3000/health returns 200 OK",
      "passes": false
    }
  ],
  "backlog": [
    {
      "description": "Add rate limiting middleware",
      "verification": "Rate limit tests pass, returns 429 on excess",
      "passes": false
    }
  ]
}
```

## Running the Loop

```bash
# Default (100 iterations max)
./ralph-builder/ralph.sh

# Custom iterations
./ralph-builder/ralph.sh -n 50

# Specific model
./ralph-builder/ralph.sh -m opus

# Validate setup without running
./ralph-builder/ralph.sh --validate-only

# Different project directory
./ralph-builder/ralph.sh -d /path/to/project

# Verbose output
./ralph-builder/ralph.sh -v
```

### Options

| Flag | Description |
|------|-------------|
| `-d, --dir PATH` | Project directory (default: current directory) |
| `-n, --iterations NUM` | Max iterations (default: 100) |
| `-m, --model MODEL` | Claude model: sonnet, opus, haiku |
| `-v, --verbose` | Verbose Claude output |
| `--validate-only` | Check setup without running loop |
| `-h, --help` | Show help |

## Exit Signals

| Signal | What Happens |
|--------|--------------|
| `<promise>COMPLETE</promise>` | All tasks done - loop exits successfully |
| `<promise>BLOCKED</promise>` | Agent stuck - loop stops, you investigate |

## Monitoring Progress

While Ralph runs, you can:

```bash
# Watch the activity log
tail -f ralph-builder/activity.md

# Check task progress
grep '"passes":' ralph-builder/plan.md | head -20
```

### When Ralph Gets Stuck

If Ralph outputs `<promise>BLOCKED</promise>` or seems stuck:

1. Open a **new Claude Code session** in your project root
2. Ask Claude to review `ralph-builder/activity.md` and `ralph-builder/plan.md`
3. Work with Claude to understand and resolve the blocker
4. Restart the loop: `./ralph-builder/ralph.sh`

## Logs

Logs are saved in `ralph-builder/.ralph-logs/`:

```
ralph-builder/.ralph-logs/
└── ralph-20260117_143052.log
```

## Troubleshooting

### "Missing required files" error

Run setup first. Open Claude and say:
```
Help me set up this project using Ralph Builder
```

### "No 'allow' permissions found"

The `.claude/settings.json` file needs permissions. During setup, Claude generates this based on your tech stack. Example:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm *)",
      "Bash(node *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Read", "Write", "Edit", "Glob", "Grep"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push *)",
      "Bash(sudo *)"
    ]
  }
}
```

### Ralph uses outdated library patterns

Install [Context7 MCP](https://github.com/upstash/context7) for up-to-date documentation. During setup, confirm it's available.

### Agent keeps doing multiple tasks per iteration

Check your `PROMPT.md` - it must clearly say:
- Do ONE task per iteration
- EXIT after completing one task
- The bash loop handles the next iteration

### Loop runs but nothing happens

1. Check `ralph-builder/activity.md` for what Ralph is doing
2. Verify `ralph-builder/plan.md` has incomplete tasks (`"passes": false`)
3. Run `./ralph-builder/ralph.sh --validate-only`

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                      SETUP PHASE                            │
│  (Interactive Claude session)                               │
│                                                             │
│  You: "Help me set up using Ralph Builder"                  │
│  Claude: Reads ralph-builder/SETUP-GUIDE.md, asks questions │
│  Claude: Generates files in ralph-builder/                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    EXECUTION PHASE                          │
│  (ralph.sh bash loop)                                       │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Iteration N                                         │   │
│  │  1. Fresh Claude context                             │   │
│  │  2. Read PROMPT.md + CLAUDE.md → find task           │   │
│  │  3. Implement + verify                               │   │
│  │  4. Update ralph-builder/plan.md + activity.md       │   │
│  │  5. Commit changes                                   │   │
│  │  6. Exit iteration                                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                │
│                            ▼                                │
│              ┌─────────────────────────┐                    │
│              │  All tasks complete?    │                    │
│              └─────────────────────────┘                    │
│                   │              │                          │
│                  Yes             No                         │
│                   │              │                          │
│                   ▼              └──────→ Next iteration    │
│         <promise>COMPLETE</promise>                         │
└─────────────────────────────────────────────────────────────┘
```

## References

- [Geoff Huntley's Ralph](https://ghuntley.com/ralph/) - Original concept
- [Ralph Wiggum Guide](https://github.com/JeredBlu/guides/blob/main/Ralph_Wiggum_Guide.md) - Community guide
- [PRPs-agentic-eng](https://github.com/Wirasm/PRPs-agentic-eng) - PRP workflow patterns
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) - Claude Code ecosystem
- [Context7 MCP](https://github.com/upstash/context7) - Library documentation lookup

---

*"Me fail English? That's unpossible!"*
