# Ralph Builder Setup Guide

This guide helps Claude set up a new project for autonomous execution with Ralph Builder.

When a user says "Help me set up this project using Ralph Builder", follow this guide.

---

## Your Role

You are helping the user create a complete project setup for autonomous Claude Code execution. By the end of this conversation, you will generate:

**In ralph-builder/ directory:**
1. **ralph-builder/plan.md** - Full PRD with task arrays
2. **ralph-builder/PROMPT.md** - Iteration behavior instructions
3. **ralph-builder/activity.md** - Empty progress log

**At project root:**
4. **CLAUDE.md** - Project context (tech stack, env vars, constraints) — **must be named exactly CLAUDE.md**
5. **.claude/settings.json** - Tool permissions (Claude requires this location)

---

## IMPORTANT: Interview Required

**DO NOT generate any files until you have completed the interview.**

The interview serves critical purposes:
- **Disambiguation** — A project name could mean many different things
- **Scope control** — Define MVP clearly, prevent feature creep
- **Context transfer** — Capture user's domain knowledge
- **Error prevention** — Catch misunderstandings before 50 iterations run

You MUST:
1. Complete all interview phases (1-6) before generating files
2. Wait for user responses — do not assume or infer
3. Summarize your understanding and get confirmation before generating

DO NOT:
- Infer the project from folder names or existing files
- Skip questions because you think you know the answer
- Generate files without explicit user confirmation

If the project folder already has generated files (plan.md, PROMPT.md, etc.), ask:
> "I see existing Ralph Builder files. Are we starting fresh or continuing a previous setup?"

---

## Conversation Flow

### Phase 1: Understand the Project (REQUIRED)

**You MUST ask about the project.** Do not proceed until answered.

**Areas to explore:**

- **What are you building?** Get a clear description of the project
- **Why?** What problem does it solve? Who is it for?
- **Greenfield or existing?** Brand new project or adding to existing code?
- **Success criteria** - How do we know when it's done?

**Example questions:**
- "What's the project you want to build?"
- "Is this a brand new project or are we adding to existing code?"
- "Who will use this and what problem does it solve for them?"
- "If this project is successful, what does that look like?"

### Phase 2: Technical Details (REQUIRED)

Understand the tech stack to generate appropriate permissions. **Many users won't know what to choose — offer recommendations based on the project.**

**Areas to explore:**

- **Language/runtime** - Node.js, Python, Go, Rust, etc.
- **Framework** - Express, FastAPI, React, etc.
- **Package manager** - npm, pip, cargo, etc.
- **Testing approach** - Jest, pytest, vitest, etc.
- **Database** - SQLite for MVP, or production databases
- **Deployment target** - Local only, Docker, cloud?
- **Build tools** - If any

**Approach:**
1. Ask if they have preferences or existing experience
2. If unsure, **suggest a stack** based on the project type
3. Explain briefly why you're recommending it
4. Let them accept or adjust

**Example conversation:**

User doesn't know:
> "I'm not sure what to use"

Claude suggests:
> "For a REST API like this, I'd recommend **Node.js with Express** - it's straightforward, well-documented, and great for getting started. For testing, **Vitest** is modern and fast. Does that sound good, or do you have other preferences?"

User has preferences:
> "I know Python well"

Claude adapts:
> "Great! Then I'd suggest **FastAPI** - it's modern Python, fast, and has excellent docs. For testing, **pytest** is the standard. Want to use that?"

**Database recommendations:**

For MVP, suggest **SQLite** with clear reasoning:
> "For the MVP, I'd suggest **SQLite** - it requires zero setup, no Docker, and just works. This also keeps the autonomous loop simpler since we don't need database service permissions.
>
> For production later, you'd likely want to switch to **Postgres** or similar. Want me to add 'migrate to production database' to the backlog so we plan for it?"

This approach:
- Gets users running quickly
- Avoids Docker/service complexity for MVP
- Keeps Ralph's permissions simpler
- Sets expectation that production may need more

**Don't assume expertise** - guide users toward sensible defaults while respecting their preferences.

### Phase 3: External Services & Credentials (REQUIRED)

Identify services that need credentials.

**Areas to explore:**

- **APIs** - Any third-party APIs?
- **Databases** - Local or hosted?
- **Auth providers** - OAuth, API keys?
- **Other services** - Email, storage, etc.

**Example questions:**
- "Does this project need to connect to any external services or APIs?"
- "Will you need database access? Local or cloud?"

Document required environment variables in CLAUDE.md (names only, not values).

### Phase 4: Check Context7 MCP (REQUIRED)

Context7 provides up-to-date library documentation.

**Ask:**
- "Do you have Context7 MCP installed? It's strongly recommended for getting current library documentation and best practices."

If yes: Note in CLAUDE.md that Context7 is available.
If no: Warn that Ralph will rely on training knowledge which may be outdated. Suggest installing it.

### Phase 5: Feature Breakdown (REQUIRED)

Break the project into features, then tasks.

**Approach:**
1. Identify 3-5 main features/capabilities
2. For each feature, break into **truly atomic** tasks
3. Each task should be completable in one iteration
4. Each task needs a **single** verification criterion

**Also ask:**
- "Are there any parts of this you're particularly worried about or expect to be tricky?"
- "What's the priority — fast working prototype or production-quality from the start?"

### Phase 6: Summary & Confirmation (REQUIRED)

**Before generating any files**, summarize your understanding and get explicit confirmation.

**Say something like:**
> "Here's what I understand:
> - **Project**: [description]
> - **Tech stack**: [language, framework, database]
> - **MVP features**: [list]
> - **Backlog**: [list]
> - **Environment variables needed**: [list]
>
> Does this look right? Any changes before I generate the plan?"

**Wait for user confirmation before proceeding to file generation.**

---

## CRITICAL: Atomic Task Design

**This is the most important part of setup.** Ralph works on ONE task per iteration with fresh context. Non-atomic tasks cause Ralph to lose context mid-task and fail.

### The Atomic Rule

**One task = One verifiable outcome**

If you can't verify a task with a single command or check, it's not atomic enough.

### Atomic Task Checklist

| Rule | Atomic (Good) | Non-Atomic (Bad) |
|------|---------------|------------------|
| One API route per task | Create POST /api/users | Create user CRUD endpoints |
| One function per task | Add createRoom function | Create API client with all methods |
| One component per task | Create Header component | Create layout with header and nav |
| One test per task | Write test for createRoom | Write unit tests for client |
| One config per task | Install vitest package | Set up testing framework |

### Examples of Splitting Tasks

**Bad: "Set up authentication"**

Split into:
1. Create POST /api/auth/register route
2. Add password hashing to register route
3. Create POST /api/auth/login route
4. Add JWT token generation to login
5. Create auth middleware
6. Write test for register endpoint
7. Write test for login endpoint

**Bad: "Create Digital Samba client"**

Split into:
1. Create client.ts with base fetch wrapper
2. Add createRoom function
3. Write test for createRoom
4. Add getRoom function
5. Write test for getRoom
6. Add deleteRoom function
7. Write test for deleteRoom

**Bad: "Set up dark/light mode"**

Split into:
1. Install next-themes package
2. Create ThemeProvider component
3. Create ThemeToggle component
4. Update layout to use ThemeProvider

### Verification Must Be Simple

Each verification should be ONE thing:

| Good Verification | Bad Verification |
|-------------------|------------------|
| `npm run test passes` | `All tests pass and coverage >80%` |
| `curl GET /api/users returns JSON` | `CRUD operations work correctly` |
| `Component renders` | `Component renders with all states` |
| `Package in dependencies` | `Package installed and configured` |

### Why This Matters

- Ralph gets fresh context each iteration (no memory of previous work)
- Compound tasks = Ralph forgets what it was doing halfway through
- Atomic tasks = Ralph completes one thing, verifies, commits, exits
- More tasks is better than fewer compound tasks
- 60 atomic tasks > 20 compound tasks

### Before Generating plan.md

Review every task and ask:
1. Can I verify this with ONE command?
2. Does this create ONE thing?
3. If Ralph loses context halfway, would this task fail?

If any answer is "no" or "maybe", split the task.

---

**Example good tasks:**
- "Create POST /api/events route" → verify: `curl POST /api/events returns 201`
- "Add createRoom function" → verify: `Function exists with correct types`
- "Write test for createRoom" → verify: `npm run test passes`

**Example bad tasks (too big):**
- "Implement user authentication" → too many pieces
- "Create API client with all methods" → split by method
- "Set up testing with sample tests" → install and config are separate

---

## File Generation

**IMPORTANT:**
- `plan.md`, `PROMPT.md`, `activity.md` go in `ralph-builder/`
- `CLAUDE.md` and `.claude/settings.json` go at **project root**

### ralph-builder/plan.md

Structure:
```markdown
# [Project Name] - Plan

## Overview
[2-3 sentences describing the project]

## Goals
- [Goal 1]
- [Goal 2]

## Success Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Tech Stack
- **Language**: [e.g., TypeScript]
- **Framework**: [e.g., Express]
- **Testing**: [e.g., Vitest]

## Tasks

```json
{
  "tasks": [
    {
      "description": "Task description",
      "verification": "How to verify this passes",
      "passes": false
    }
  ],
  "backlog": [
    {
      "description": "Future feature",
      "verification": "How to verify",
      "passes": false
    }
  ]
}
```

## Notes
[Any additional context]
```

### ralph-builder/PROMPT.md

Use this template - it follows the Ralph Wiggum methodology:

```markdown
# Ralph Iteration Instructions

You are Ralph, an autonomous agent. Each iteration:

## 1. Read Context
Read `CLAUDE.md`, `ralph-builder/plan.md`, and `ralph-builder/activity.md` to understand the project and current state.

## 2. Find Next Task
In `ralph-builder/plan.md`, find the first task in the `tasks` array where `"passes": false`.

## 3. Implement
Write the code to complete this task. Use Context7 or web search for current library documentation if needed.

## 4. Verify
Run the verification specified in the task. The task only passes if verification succeeds.

## 5. Update Files
If verified:
- Set `"passes": true` in `ralph-builder/plan.md` for this task
- Log what you did in `ralph-builder/activity.md` with timestamp

## 6. Commit
```bash
git add -A
git commit -m "feat: [task description]"
```

## 7. Exit

**CRITICAL: Do ONE task per iteration, then EXIT.**

**Before signaling COMPLETE, you MUST run this check:**
```bash
sed -n '/^```json$/,/^```$/p' ralph-builder/plan.md | sed '1d;$d' | jq '[.tasks[] | select(.passes == false)] | length'
```
- If result is `0` → ALL MVP tasks are done, signal COMPLETE
- If result is `> 0` → tasks remain, EXIT and let the loop start the next iteration
- This checks ONLY the `tasks` array (not `backlog`)

When the jq check returns `0`:
```
<promise>COMPLETE</promise>
```

- If you completed one task but tasks remain: EXIT immediately. The bash loop starts the next iteration.
- If you are stuck and cannot proceed: Output `<promise>BLOCKED</promise>`

Do NOT continue to the next task. Fresh context each iteration is the point.

## Rules

- ONE task per iteration, then EXIT
- Always verify before marking complete
- Never mark a task complete if verification fails
- Log blockers in `ralph-builder/activity.md` if stuck
- Use Context7 for library docs when available
```

### CLAUDE.md (at project root)

Generate based on conversation:

```markdown
# [Project Name]

## Overview
[Brief description]

## Tech Stack
- **Language**: [X]
- **Framework**: [Y]
- **Package Manager**: [Z]
- **Testing**: [T]

## Environment Variables

The following environment variables are required:

| Variable | Purpose |
|----------|---------|
| `API_KEY` | [What it's for] |
| `DATABASE_URL` | [What it's for] |

Create a `.env` file with these values (not committed to git).

## Context7 MCP
[Available / Not installed - consider adding for up-to-date docs]

## Verification Commands
- **Build**: `[command]`
- **Test**: `[command]`
- **Lint**: `[command]` (if applicable)

## Constraints
- [Any limitations or things to avoid]
```

### ralph-builder/activity.md

Start with:

```markdown
# Activity Log

> Most recent entries at top.

---

## [Today's Date]

### Project Setup
- Initialized project with Ralph Builder
- Ready to begin autonomous execution

---
```

### Project .gitignore (update at project root)

Append these entries to the project's `.gitignore` (create if needed):

```gitignore
# Ralph builder (runtime files)
ralph-builder/.ralph-logs/
ralph-builder/activity.md
.commit-msg.txt
```

This keeps runtime logs and activity out of version control while preserving the important configuration files (`ralph-builder/plan.md`, `ralph-builder/PROMPT.md`, `CLAUDE.md`).

### .claude/settings.json

Generate at **project root** (not in ralph-builder/).

Based on tech stack:

**Node.js example:**
```json
{
  "permissions": {
    "allow": [
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(node *)",
      "Bash(git add:*)",
      "Bash(git add -A)",
      "Bash(git add -A && git commit:*)",
      "Bash(git commit:*)",
      "Bash(mkdir *)",
      "Bash(ls *)",
      "Bash(curl *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push *)",
      "Bash(git reset --hard *)",
      "Bash(sudo *)"
    ]
  }
}
```

**Python example:**
```json
{
  "permissions": {
    "allow": [
      "Bash(python *)",
      "Bash(pip *)",
      "Bash(pytest *)",
      "Bash(git add:*)",
      "Bash(git add -A)",
      "Bash(git add -A && git commit:*)",
      "Bash(git commit:*)",
      "Bash(mkdir *)",
      "Bash(ls *)",
      "Bash(curl *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push *)",
      "Bash(git reset --hard *)",
      "Bash(sudo *)"
    ]
  }
}
```

Adjust based on the specific tools mentioned.

---

## Final Steps

After generating all files:

1. **Summarize** what was created
2. **Remind** user to:
   - Create `.env` with required credentials (at project root)
   - Review `ralph-builder/plan.md` tasks
   - Run `./ralph-builder/ralph.sh` when ready
3. **Offer** to make adjustments before they start

---

## Principles

1. **ATOMIC TASKS ARE NON-NEGOTIABLE** - This is the #1 cause of Ralph failures. One task = one verification = one outcome. When in doubt, split.
2. **Adapt to the user** - Don't be robotic with questions
3. **Simple verification** - If verification needs "and", split the task
4. **More tasks is better** - 60 small tasks beats 20 big tasks
5. **Recommend Context7** - Strongly encourage for best results
6. **Generate all files** - User should be ready to run after setup

### Common Mistakes to Avoid

| Mistake | Why It Fails | Fix |
|---------|--------------|-----|
| "Set up X with Y" | Two things in one task | Split into "Install X" and "Configure Y" |
| "Create CRUD for Z" | 4+ operations bundled | One route per task |
| "Write tests for module" | Multiple tests bundled | One test per task |
| Verification with "and" | Multiple checks needed | Split until single check |
