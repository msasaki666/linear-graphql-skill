# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**linear-graphql-skill** is a Claude Skill for managing Linear issues via the GraphQL API using `curl` and bash. It is designed as an MCP-free alternative that minimizes context window consumption. There is no build step, no package manager, and no compiled output — the project is a collection of shell scripts and markdown documentation.

## Architecture

The project has three layers:

1. **SKILL.md** — The primary skill definition. Describes the auto-authentication flow (MCP Vault → OAuth → Bearer token) and the base `curl` pattern for GraphQL calls. This is the entry point Claude reads when the skill is invoked.

2. **scripts/linear_api.sh** — Helper functions (`linear_query`, `linear_query_with_vars`, `linear_whoami`, `linear_teams`, `linear_projects`, `linear_team_states`) that wrap common API operations. All require `LINEAR_API_TOKEN` to be set and output JSON.

3. **references/** — Reference documentation:
   - `oauth-setup.md` — Two OAuth flows (Client Credentials for automation, Authorization Code for user-specific ops), MCP Vault integration, troubleshooting table
   - `graphql-queries.md` — Ready-to-use GraphQL queries (teams, projects, issues, search) and mutations (create/update issues, add comments) with pagination patterns

## Key Design Decisions

- All commands must be wrapped in `bash -c '...'` because claude.ai defaults to `/bin/sh`
- Credentials are stored in MCP Vault (`linear-client-id`, `linear-client-secret`), never in project files
- GraphQL variables should be used (via `linear_query_with_vars`) for safe handling of special characters
- Client Credentials flow tokens expire after 30 days; Authorization Code tokens after 24 hours
- Only `curl`, `jq`, and `bash` are required — no external CLI tools or dependencies

## Commands

There is no build, lint, or test system. To verify connectivity after authentication:

```bash
source scripts/linear_api.sh
export LINEAR_API_TOKEN="<token>"
linear_whoami
```
