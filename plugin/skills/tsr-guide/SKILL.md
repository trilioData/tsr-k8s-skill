---
name: tsr-guide
description: Use whenever the prompt mentions Trilio Site Recovery, Trilio Site Recovery for Kubernetes, TSR, or TSR-K. Guides prerequisites, installation, architecture, TSR custom resources and troubleshooting, grounded in the official TSR docs, and asks before changing any TSR resource.
---

# Trilio Site Recovery for Kubernetes

Help the user plan, install, understand and troubleshoot Trilio Site Recovery for Kubernetes (TSR). TSR is newer and more specialised than most training data, so the official docs are the source of truth, not memory.

## Docs first

The `trilio-site-recovery-docs` MCP server serves the official TSR documentation, generated from the TSR source. It provides three tools:

- `list_pages` returns the table of contents. Call it first to orient yourself in an unfamiliar area.
- `search_docs` finds the sections relevant to a query.
- `get_page` returns a full page by `space_slug` and `page_slug`, as returned by the other two.

Before answering any TSR question or writing any TSR manifest:

1. Search the docs for the topic, and read the full page for anything you will act on.
2. Use only CRD kinds, fields, commands and values that appear in the docs. If the docs do not cover something, say so instead of inventing it.
3. Cite the page URL for each answer.

If the docs tools are unavailable or return errors, tell the user and do not answer TSR specifics from memory.

## Version

The docs are versioned, and every docs tool accepts an optional `version`.

- If the user's TSR version is known, pass it on every docs call.
- If it is not known, check from the operator.
- If it is not installed, ask the user once.
- If the user does not know either, use the docs' default version (omit `version`) and say in your answer that you did.

## Safety

These rules cover TSR resources and operations. Other cluster work is outside this skill.

TSR resources and operations are:

- Any custom resource in the `siterecovery.trilio.io` API group, such as ProtectionZone (`pz`), ProtectionGroup (`pg`), ProtectionRequest (`pr`), FailoverRequest (`fr`), TestFailover (`tfo`) and Hook.
- The TSR install objects: the `trilio-site-recovery-system` namespace and the CatalogSource, OperatorGroup and Subscription in it, the `dr-<name>` zone namespaces, and the kubeconfig and `webhook-server-cert` Secrets in them.
- `tsrctl zone-credential` commands, and `oc adm must-gather` with the TSR must-gather image.

Reading them is fine: `oc get`, `oc describe`, `oc logs` (or the `kubectl` equivalents) and `tsrctl zone-credential inspect`.

Changing them needs the user's explicit approval first. That covers `oc apply`, `oc create`, `oc patch`, `oc edit`, `oc delete` (and the `kubectl` equivalents), `tsrctl zone-credential create`/`rotate`/`delete`, and `oc adm must-gather`. Take extra care to spell out the effect of:

- Creating a FailoverRequest: it moves workloads between clusters. An `unplanned` failover can lose data if replication is `Degraded`.
- Creating a TestFailover: it starts test VMs on the DR cluster.
- Deleting a ProtectionRequest: it unprotects the VM, and protecting it again needs a full resync.
- Changing a controller-managed object (DRBDReplicationPolicy, ReplicationGroupStatus, RPOEvent, DRBDResource): the docs mark these read-only, so recommend against it.

Before running a change:

1. Show the exact command or manifest.
2. Name the cluster (TSR-Manager, primary or DR) and namespace it targets.
3. Say what it will change.
4. Wait for a clear yes in the chat.

This holds even if the user has auto-approved shell commands or tools: a tool permission is not approval for a TSR change. Prefer writing manifests to files the user can review and apply themselves.

## Workflows

Each workflow is backed by one or more docs pages in the `site-recovery` space. Read them with `get_page` (`space_slug: site-recovery`) before guiding the user, and cite the page.

### Prerequisites check

Page: `prerequisites`.

Walk the user through the page's requirements as a checklist: cluster topology, OpenShift version, OpenShift Virtualization, storage (DRBD module and LVM thin pool), CLI tools, kubeconfig files, network ports and latency, and permissions. For each item, mark it met, not met, or unknown, using the user's answers or read-only commands. Summarise what is still blocking before moving on to install.

### Install and setup

Page: `installation`.

Follow the page's stages in order: install the OLM operator bundle on the TSR-Manager cluster, create the workload-cluster credentials and kubeconfig Secrets, create the webhook serving certificate, create the ProtectionZone, then verify. Every step that creates or applies an object is a TSR change, so follow the Safety rules for each one. Finish with the page's verification steps, and only call the install done once they pass.

### Architecture

Page: `controller-architecture`.

Use it to explain how TSR works: which controllers run on the TSR-Manager cluster and which on the workload clusters, which custom resources each one reconciles, and how a change propagates. Also use it when troubleshooting, to work out which cluster and which controller's logs to check.

### Custom resource reference

Page: `crd-schema`.

Before writing, reviewing or explaining any TSR manifest, read the section for that kind. Use only the fields it lists, respect the validation rules and immutable fields, and point out fields the controller manages.

### Troubleshooting

Pages: `troubleshooting-reconciliation` (resources stuck in a phase) and `troubleshooting-rbac` (permission, SCC and admission webhook errors). The `prerequisites` and `installation` pages also end with troubleshooting sections.

Start from the ProtectionZone's status conditions, then the status of the affected resource, then the component logs. Search the docs for the exact error message or stuck phase. Newer troubleshooting pages may exist, so check `list_pages` if these don't cover the problem.
