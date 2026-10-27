# Trilio Site Recovery for coding agents

This repository contains a plugin that helps coding agents set up and operate [Trilio Site Recovery](https://trilio.io) (TSR) on Kubernetes and OpenShift: checking prerequisites, installing TSR, configuring disaster recovery between clusters, running failover and failback, and troubleshooting.

The plugin has two parts:

- **The TSR docs MCP server.** Installing the plugin connects the agent to the official TSR documentation, which is generated from the TSR source. The agent searches it instead of relying on what it remembers about TSR.
- **The `tsr-guide` skill.** It runs when you mention Trilio Site Recovery, Trilio Site Recovery for Kubernetes, TSR or TSR-K. It guides prerequisites, installation, architecture, custom resources and troubleshooting from the matching docs pages, cites the pages it used, and matches the docs to your TSR version.

**Safety:** for TSR resources and operations, the agent may freely run read-only commands such as `oc get` or `oc describe`. Before anything that changes a TSR resource (applying, patching or deleting TSR custom resources or install objects, `tsrctl zone-credential` changes, or starting a failover or test failover), it shows you the exact command or manifest and the cluster it targets, then waits for your explicit yes. This applies even if you've auto-approved shell commands.

Workflows cover the TSR setup path. Failover and other day-2 operations aren't scripted yet; the agent answers them from the docs, under the same rules.

## Instructions

The plugin is available for Claude Code, Codex, Cursor and Junie.

### Claude Code

#### Installation

Run the following commands inside a Claude Code session.

1. Add this repository as a marketplace:
```
/plugin marketplace add triliodata/tsr-k8s-skill
```

2. Install the plugin:
```
/plugin install trilio-site-recovery@trilio-claude-marketplace
```

#### Usage

Claude Code invokes the skill automatically when a task involves TSR. To invoke it explicitly:

```
/trilio-site-recovery:tsr-guide
```

#### Updating

```bash
claude plugin marketplace update trilio-claude-marketplace
claude plugin update trilio-site-recovery@trilio-claude-marketplace
```

Then run `/reload-plugins` in an open session.

### Codex

#### Installation

Run the following commands in a terminal.

1. Add this repository as a marketplace:
```
codex plugin marketplace add triliodata/tsr-k8s-skill
```

2. Install the plugin:
```
codex plugin add trilio-site-recovery@trilio-codex-marketplace
```

If `codex mcp list` doesn't show the `trilio-site-recovery-docs` server after installing, add it by hand, using the URL from [Updating the docs URL](#updating-the-docs-url):

```bash
codex mcp add trilio-site-recovery-docs --url "<docs URL>"
```

#### Updating

Refresh the marketplace and reinstall the plugin so Codex replaces its cached copy:

```bash
codex plugin marketplace upgrade trilio-codex-marketplace
codex plugin remove trilio-site-recovery@trilio-codex-marketplace
codex plugin add trilio-site-recovery@trilio-codex-marketplace
```

### Cursor

#### Installation

1. Add this repository as a marketplace by running the following command in a terminal:
```
cursor-agent plugin marketplace add https://github.com/triliodata/tsr-k8s-skill
```

2. Install the plugin with the `/plugins` command inside a Cursor session.

#### Updating

```bash
cursor-agent plugin marketplace update trilio-cursor-marketplace
```

Reopen Cursor. If the plugin is still on the previous version, reinstall it with the `/plugins` command.

### Junie

#### Installation

Run the following commands inside a Junie CLI session.

1. Add this repository as a marketplace:
```
/extensions marketplace add triliodata/tsr-k8s-skill
```

2. Install the extension:
```
/extensions install trilio-site-recovery
```

If Junie doesn't list the `trilio-site-recovery-docs` MCP server after installing, add it by hand to `.junie/mcp/mcp.json` in your project (or `~/.junie/mcp/mcp.json` for all projects), using the URL from [Updating the docs URL](#updating-the-docs-url):

```json
{
  "mcpServers": {
    "trilio-site-recovery-docs": {
      "url": "<docs URL>"
    }
  }
}
```

#### Updating

```
/extensions update trilio-site-recovery
```

## Updating the docs URL

The TSR docs MCP server is at:

```
https://docs-tsr.trilio.io/api/mcp/mark-reid/trilio-site-recovery-for-kubernetes
```

If this URL changes, update it in all of these places, then bump the version in every manifest and add a CHANGELOG entry:

- `plugin/.mcp.json` (Claude Code and Cursor)
- `plugin/mcp.json` (Codex)
- `plugin/mcp/.mcp.json` (Junie)
- `DOCS_URL` in `scripts/check.sh`
- this section

## Development

`scripts/check.sh` checks that the manifests, MCP files, skill and README stay consistent, and runs `claude plugin validate` when the `claude` CLI is installed. It needs `jq`.

```bash
sh scripts/check.sh                  # offline checks
CHECK_ONLINE=1 sh scripts/check.sh   # also confirms the docs MCP server responds
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to change and evaluate the plugin.

## License

[Apache-2.0](LICENSE)
