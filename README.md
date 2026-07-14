# psaxde skills

Personal Codex and Claude skill collection.

Each top-level directory is one complete skill folder. Keep generated outputs,
temporary work files, and `node_modules` out of Git.

## Skills

- `pinterest-content-ops` - create, preview, validate, schedule, publish, and verify reusable Pinterest pin batches from source-backed products, articles, recipes, or campaigns.
- `ui-from-mockup` - recreate or refine UI from mockups/screenshots with screenshot capture, layout snapshots, visual diffs, region crops, and global-shift diagnostics.

## Install locally

Clone the repository:

```bash
git clone git@github.com:psaxde/skills.git ~/skills
```

Install a skill for Codex by symlinking it into `~/.codex/skills` (replace
`<skill-name>` with a directory listed above):

```bash
mkdir -p ~/.codex/skills
ln -sfn ~/skills/<skill-name> ~/.codex/skills/<skill-name>
```

For Claude Code, either point Claude at the same skill or symlink it separately:

```bash
mkdir -p ~/.claude/skills
ln -sfn ~/skills/<skill-name> ~/.claude/skills/<skill-name>
```

If a skill has Node-based helper scripts, follow that skill's setup notes. For
example:

```bash
cd ~/skills/ui-from-mockup/scripts
npm install
npx playwright install chromium
```

## Add another skill

Add another complete skill folder at the repository root:

```text
my-skill/
  SKILL.md
  agents/openai.yaml
  scripts/
  references/
  assets/
```

Validate before committing when possible:

```bash
python "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" ./my-skill
```
