# Contributing

Thank you for contributing to the Trilio Site Recovery plugin. Fixes and improvements of any size are welcome.

This plugin tells coding agents how to work with customers' disaster recovery setups, so a wrong instruction can cost someone a failed install or a bad failover. Every change is reviewed with that in mind.

## Discuss substantial changes first

Before a substantial change, such as a new workflow, a change to the safety rules, or support for another agent, open a ticket in the TSR Jira project describing the proposal and how you plan to evaluate it. Typo fixes and other obvious corrections don't need a ticket.

## Repository layout

| Path | What it is |
|------|------------|
| `.claude-plugin/`, `.cursor-plugin/`, `.agents/plugins/`, `.junie-extension/` | Marketplace files for Claude Code, Cursor, Codex and Junie. Each points at `./plugin`. |
| `plugin/.claude-plugin/`, `plugin/.codex-plugin/`, `plugin/.cursor-plugin/`, `plugin/extension.json` | The plugin manifest for each agent. |
| `plugin/.mcp.json`, `plugin/mcp.json`, `plugin/mcp/.mcp.json` | The TSR docs MCP server registration: Claude Code and Cursor, Codex, and Junie respectively. |
| `plugin/skills/tsr-guide/SKILL.md` | The skill itself. |
| `scripts/check.sh` | Consistency checks for all of the above. |

## Set up and test locally

You need `jq`. The [Claude Code](https://claude.com/product/claude-code) CLI is optional, but `scripts/check.sh` uses it to validate the plugin when it is installed.

Run the checks:

```bash
sh scripts/check.sh                  # offline checks
CHECK_ONLINE=1 sh scripts/check.sh   # also confirms the docs MCP server responds
```

Try your checkout in Claude Code without installing it:

```bash
claude --plugin-dir ./plugin
```

## Changing the skill

`plugin/skills/tsr-guide/SKILL.md` has four sections. Keep these properties when you edit it:

- **Docs first.** The agent reads the docs over MCP before answering or writing manifests, and says so when the docs are unavailable instead of answering from memory. Don't weaken this.
- **Point at docs pages; don't copy them.** Workflows name the docs page to read (`space_slug: site-recovery`, `page_slug: ...`) and describe how to guide the user. Avoid pasting long command blocks or field tables from the docs into the skill: they go stale as TSR changes, and they cost tokens on every use.
- **Check that page slugs exist.** Before you reference a page, confirm `get_page` returns it. Some pages listed by `list_pages` return "Page not found".
- **Safety covers TSR resources and operations.** Any change to a TSR resource needs the user's explicit approval in chat, even when shell commands are auto-approved. Changes to the safety rules always need a ticket and review.
- **Trigger phrases.** The `description` must keep naming Trilio Site Recovery, Trilio Site Recovery for Kubernetes, TSR and TSR-K.

`scripts/check.sh` enforces the section headings, workflow headings, page slugs and key phrases. If you add or rename a workflow, update `check_skill` in the same change.

### Evaluate the change

A skill change should demonstrably improve how agents behave. Passing `scripts/check.sh` is necessary but not enough.

1. Pick a few representative prompts for the behaviour you're changing, for example "What do I need before installing TSR?" or "My ProtectionRequest is stuck in Syncing".
2. Run them against the current skill and against your change, with the same agent and model. For a headless run:
   ```bash
   claude --plugin-dir ./plugin -p "<prompt>" --output-format stream-json --verbose
   ```
   Allow the docs tools with `--allowedTools`. Disallow `Bash`, `Write` and `Edit` unless the test needs them, and never run tests that can change a real cluster.
3. For each run, check that the skill triggered, which docs pages the agent read, that it cited them, and that it ran no command that changes a TSR resource without asking.
4. Include at least one run where the docs tools are unavailable, and check that the agent refuses to answer from memory.
5. Put the prompts and results in the pull request.

## Changing manifests or releasing a version

The version must match everywhere. When you bump it:

1. Update `version` in `plugin/.claude-plugin/plugin.json`, `plugin/.codex-plugin/plugin.json` and `plugin/.cursor-plugin/plugin.json`.
2. Update `extensions[0].version` in `.junie-extension/marketplace.json`.
3. Update `VERSION` in `scripts/check.sh`.
4. Add an entry at the top of `CHANGELOG.md`.

Keep the marketplace `metadata.version` fields in step too. `scripts/check.sh` doesn't check those yet.

If the docs MCP URL changes, follow [Updating the docs URL](README.md#updating-the-docs-url) in the README.

## Supporting all four agents

Anything you add to the plugin, such as an MCP server, agent or command, has to work in Claude Code, Codex, Cursor and Junie. Each agent reads its own manifest and file format. Check each agent's current plugin documentation, and test the agents you can. If an agent can't load the new component from the plugin, document a manual setup step for it in the README, as the README already does for the docs MCP server in Codex and Junie.

## Commits and pull requests

- Name your branch after the Jira ticket, for example `TSR-244`.
- Write commit messages as `<icon> TSR-<ticket> <message>`, for example `✨ TSR-244 add tsr-guide skill`. The icon is one of:

  | Icon | Use for |
  |------|---------|
  | ✨ | A new feature |
  | 🌱 | Maintenance, such as refactoring, tooling or dependency updates |
  | 📖 | A documentation update |
  | 🐛 | A bug fix |
- Keep each pull request to one change. Split unrelated fixes into separate pull requests.
- Read the complete diff before opening the pull request, including anything an AI tool wrote. You are responsible for what you submit.
- Run `sh scripts/check.sh` and make sure it passes.

The pull request description should explain the problem, the change and why it's right, how you evaluated it (for skill changes), which checks you ran, and any known limitations.
