# Ralph-Builder

Structured wrapper for autonomous AI coding, built on Geoff Huntley's [Ralph](https://ghuntley.com/ralph/) concept.

## Project Goal

Make ralph-builder portable and open source. Users clone it into their greenfield project and run the setup interview to generate a PRD and task plan.

## Architecture Decisions

### Directory Structure (When Used in a Project)

```
my-project/                      ← PROJECT_DIR (code lives here)
├── .claude/settings.json        ← Must be at project root (Claude requirement)
├── .env                         ← User's secrets (not committed)
├── CLAUDE.md                    ← Generated project context
├── ralph-builder/               ← BUILDER_DIR (cloned into project)
│   ├── ralph.sh                 ← Main loop script
│   ├── SETUP-GUIDE.md           ← Interactive PRD interview
│   ├── plan.md                  ← Generated task database
│   ├── PROMPT.md                ← Generated iteration instructions
│   ├── activity.md              ← Progress log
│   └── .ralph-logs/             ← Execution logs
└── src/                         ← Actual project code
```

### Key Design Decisions

1. **Most generated files stay in ralph-builder/** - Except CLAUDE.md which goes at project root for better visibility

2. **ralph.sh uses two paths:**
   - `BUILDER_DIR` = where ralph.sh and config files live (`ralph-builder/`)
   - `PROJECT_DIR` = where code gets written (parent directory)

3. **.claude/settings.json at project root** - Claude Code requires this location for permissions

4. **No setup.sh script** - User runs `claude` and follows SETUP-GUIDE.md interactively

5. **Installation via git clone** - Simple, no package manager needed:
   ```bash
   git clone https://github.com/xxx/ralph-builder ./ralph-builder
   ```

6. **PROMPT.md references paths:**
   ```markdown
   Read `ralph-builder/plan.md` and find the first task...
   Update `ralph-builder/activity.md`...
   Reference `CLAUDE.md` (at project root) for project context.
   ```

## Attribution

Based on Geoff Huntley's Ralph concept: https://ghuntley.com/ralph/

The original insight:
```bash
while :; do cat PROMPT.md | claude-code ; done
```

This wrapper adds:
- Interactive PRD generation workflow
- Atomic task management with plan.md
- Progress tracking and exit signals
- Portable project structure

## Related Projects

This is part of a blog post announcing three open source projects:
- **ralph-builder** (this repo)
- **virtual-event-platform** - Demo app built with ralph-builder + Digital Samba
- **samba-qa-ralph** - MCP server for AI-powered testing
