#!/usr/bin/env sh
# Checks the invariants that tie the plugin's files together: names, versions,
# the docs MCP URL, and the rules the skill must carry.
#
# Run from the repo root:
#   sh scripts/check.sh                  # offline checks
#   CHECK_ONLINE=1 sh scripts/check.sh   # also probes the docs MCP server
set -u

PLUGIN_NAME="trilio-site-recovery"
VERSION="0.1.0"
MCP_SERVER="trilio-site-recovery-docs"
DOCS_URL="https://docs-tsr.trilio.io/api/mcp/mark-reid/trilio-site-recovery-for-kubernetes"

failures=0

fail() {
	echo "FAIL: $1"
	failures=$((failures + 1))
}

ok() {
	echo "ok: $1"
}

# json_get FILE FILTER sets $got to the jq result, or records a failure and
# returns 1. It assigns rather than prints so that fail() never runs in a
# subshell, where the failure count would be lost.
json_get() {
	if [ ! -f "$1" ]; then
		fail "$1: missing"
		return 1
	fi
	if ! got=$(jq -r "$2" "$1" 2>/dev/null); then
		fail "$1: cannot evaluate $2"
		return 1
	fi
}

# expect FILE FILTER WANT records a failure unless FILTER on FILE yields WANT.
expect() {
	json_get "$1" "$2" || return 0
	if [ "$got" = "$3" ]; then
		ok "$1 $2"
	else
		fail "$1 $2 is '$got', want '$3'"
	fi
}

check_manifests() {
	for f in $(find .claude-plugin .cursor-plugin .agents .junie-extension plugin -name '*.json' 2>/dev/null); do
		jq empty "$f" 2>/dev/null || fail "$f: invalid JSON"
	done

	for f in plugin/.claude-plugin/plugin.json plugin/.codex-plugin/plugin.json plugin/.cursor-plugin/plugin.json plugin/extension.json; do
		expect "$f" .name "$PLUGIN_NAME"
	done
	for f in plugin/.claude-plugin/plugin.json plugin/.codex-plugin/plugin.json plugin/.cursor-plugin/plugin.json; do
		expect "$f" .version "$VERSION"
		expect "$f" .skills ./skills/
	done
	expect plugin/.cursor-plugin/plugin.json .mcpServers ./.mcp.json
	expect plugin/.codex-plugin/plugin.json .mcpServers ./mcp.json

	expect .claude-plugin/marketplace.json .name trilio-claude-marketplace
	expect .cursor-plugin/marketplace.json .name trilio-cursor-marketplace
	for f in .claude-plugin/marketplace.json .cursor-plugin/marketplace.json; do
		expect "$f" '.plugins | length' 1
		expect "$f" '.plugins[0].name' "$PLUGIN_NAME"
		expect "$f" '.plugins[0].source' ./plugin
	done

	expect .agents/plugins/marketplace.json .name trilio-codex-marketplace
	expect .agents/plugins/marketplace.json '.plugins | length' 1
	expect .agents/plugins/marketplace.json '.plugins[0].name' "$PLUGIN_NAME"
	expect .agents/plugins/marketplace.json '.plugins[0].source.path' ./plugin

	expect .junie-extension/marketplace.json .name trilio-junie-marketplace
	expect .junie-extension/marketplace.json '.extensions | length' 1
	expect .junie-extension/marketplace.json '.extensions[0].name' "$PLUGIN_NAME"
	expect .junie-extension/marketplace.json '.extensions[0].source' ./plugin
	expect .junie-extension/marketplace.json '.extensions[0].version' "$VERSION"

	if command -v claude >/dev/null 2>&1; then
		for target in . plugin; do
			if out=$(claude plugin validate "$target" 2>&1); then
				ok "claude plugin validate $target"
			else
				fail "claude plugin validate $target:
$out"
			fi
		done
	else
		ok "claude plugin validate skipped (claude not on PATH)"
	fi
}

# Each agent reads its own MCP file; all of them must name the same server
# and URL.
check_mcp() {
	server=".mcpServers[\"$MCP_SERVER\"]"
	for f in plugin/.mcp.json plugin/mcp.json plugin/mcp/.mcp.json; do
		expect "$f" '.mcpServers | length' 1
		expect "$f" "$server.url" "$DOCS_URL"
	done
	expect plugin/.mcp.json "$server.type" http
	expect plugin/mcp.json '."$schema"' https://agent-plugins.org/schemas/1.0.0/mcp.schema.json
	expect plugin/mcp.json "$server.type" streamable-http

	if [ "${CHECK_ONLINE:-}" = 1 ]; then
		tools=$(curl -s -m 30 -X POST "$DOCS_URL" \
			-H 'Content-Type: application/json' \
			-H 'Accept: application/json, text/event-stream' \
			-d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')
		for tool in search_docs get_page list_pages; do
			case "$tools" in
			*"\"$tool\""*) ok "docs MCP lists $tool" ;;
			*) fail "docs MCP does not list $tool" ;;
			esac
		done
	fi
}

SKILL=plugin/skills/tsr-guide/SKILL.md

# frontmatter KEY prints the value of KEY from the skill's frontmatter.
frontmatter() {
	awk 'NR == 1 && /^---$/ { on = 1; next } on && /^---$/ { exit } on' "$SKILL" |
		sed -n "s/^$1: *//p"
}

# section HEADING prints the body of the "## HEADING" section.
section() {
	awk -v h="## $1" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$SKILL"
}

# expect_text LABEL TEXT NEEDLE... records a failure for each NEEDLE that TEXT
# lacks (case-insensitive).
expect_text() {
	label=$1 text=$2
	shift 2
	for needle in "$@"; do
		if printf '%s\n' "$text" | grep -qiF -- "$needle"; then
			ok "$label mentions '$needle'"
		else
			fail "$label does not mention '$needle'"
		fi
	done
}

check_skill() {
	if [ ! -f "$SKILL" ]; then
		fail "$SKILL: missing"
		return
	fi

	name=$(frontmatter name)
	if [ "$name" = tsr-guide ]; then
		ok "skill name"
	else
		fail "skill name is '$name', want 'tsr-guide'"
	fi
	# The phrases that should invoke the skill.
	expect_text "skill description" "$(frontmatter description)" \
		"Trilio Site Recovery" "Trilio Site Recovery for Kubernetes" TSR TSR-K

	for heading in "Docs first" Version Safety Workflows; do
		if grep -qx "## $heading" "$SKILL"; then
			ok "skill has '## $heading'"
		else
			fail "skill lacks '## $heading'"
		fi
	done

	expect_text "skill" "$(cat "$SKILL")" search_docs get_page list_pages
	expect_text "Docs first section" "$(section 'Docs first')" unavailable
	expect_text "Version section" "$(section Version)" "ask" "default version"
	# Safety covers TSR resources and operations only. TSR installs through
	# OLM, so Helm has no place in it.
	safety=$(section Safety)
	expect_text "Safety section" "$safety" "TSR resources" siterecovery.trilio.io \
		"oc apply" FailoverRequest TestFailover tsrctl "even if"
	if printf '%s\n' "$safety" | grep -qi helm; then
		fail "Safety section mentions Helm"
	else
		ok "Safety section does not mention Helm"
	fi

	workflows=$(section Workflows)
	for sub in "Prerequisites check" "Install and setup" Architecture \
		"Custom resource reference" Troubleshooting; do
		if printf '%s\n' "$workflows" | grep -qx "### $sub"; then
			ok "Workflows has '### $sub'"
		else
			fail "Workflows lacks '### $sub'"
		fi
	done
	expect_text "Workflows section" "$workflows" prerequisites installation \
		controller-architecture crd-schema troubleshooting-reconciliation troubleshooting-rbac
}

check_docs() {
	# The README shows the URL in exactly one place, so a URL change has a
	# single spot to edit there.
	count=$(grep -oF "$DOCS_URL" README.md 2>/dev/null | wc -l | tr -d ' ')
	if [ "$count" = 1 ]; then
		ok "README shows the docs URL once"
	else
		fail "README shows the docs URL $count times, want 1"
	fi
	for heading in "Claude Code" Codex Cursor Junie "Updating the docs URL"; do
		if grep -qx "### $heading\|## $heading" README.md 2>/dev/null; then
			ok "README has '$heading'"
		else
			fail "README lacks a '$heading' section"
		fi
	done

	# Codex and Junie bundled-MCP support is unverified, so the README gives a
	# manual fallback for each.
	expect_text README.md "$(cat README.md 2>/dev/null)" "codex mcp add" ".junie/mcp/mcp.json"

	expect_text LICENSE "$(cat LICENSE 2>/dev/null)" "Apache License" "Version 2.0"
	expect_text CHANGELOG.md "$(cat CHANGELOG.md 2>/dev/null)" "## 0.1.0"
}

check_manifests
check_mcp
check_skill
check_docs

if [ "$failures" -gt 0 ]; then
	echo "$failures check(s) failed"
	exit 1
fi
echo "all checks passed"
