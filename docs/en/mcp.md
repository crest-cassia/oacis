---
layout: default
title: "MCP Server"
lang: en
next_page: tips
---

# MCP Server for AI agents

---

OACIS ships an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server, `bin/oacis_mcp`, which lets AI agents such as Claude submit and monitor simulation jobs.
An agent connected to this server can explore parameter spaces autonomously: create parameter sets, submit runs, poll their status, read result files, and trigger analyzers.

The server speaks JSON-RPC over stdio and accesses the OACIS database in-process, exactly like the [Ruby API]({{ site.baseurl }}/{{ page.lang }}/api.html). Jobs created through it are picked up and submitted to remote hosts by the ordinary OACIS background workers.

## Setup

The command must run on the machine where OACIS is installed (it loads the Rails environment).

With [Claude Code](https://claude.com/claude-code):

```shell
claude mcp add oacis -- /path/to/oacis/bin/oacis_mcp
```

or in a project's `.mcp.json`:

```json
{
  "mcpServers": {
    "oacis": { "command": "/path/to/oacis/bin/oacis_mcp" }
  }
}
```

If you run OACIS with docker (oacis_docker), connect through `docker exec` (note `-i`, without `-t`):

```shell
claude mcp add oacis -- docker exec -i -u oacis my_oacis /home/oacis/oacis/bin/oacis_mcp
```

## Security model

- The server is stdio-only; it opens no network port. Whoever can execute `bin/oacis_mcp` gets the same database access as `bin/oacis_ruby`.
- When `OACIS_ACCESS_LEVEL` is `0`, or when the environment variable `OACIS_MCP_READONLY=1` is set, the three write tools are hidden and rejected — the agent can only inspect.
- There are no destructive tools: agents cannot delete simulators, parameter sets, runs, or analyses, and cannot modify simulator/host configurations.
- File access is restricted to the result directories of runs and analyses, with size limits.

## Tools

| Tool | Type | Purpose |
|------|------|---------|
| `list_simulators` | read | Simulators with parameter definitions and analyzers |
| `list_hosts` | read | Hosts/host groups with host parameter definitions |
| `search_parameter_sets` | read | Query parameter sets by parameter values, with run status counts |
| `get_parameter_set` | read | One parameter set, its runs, and average results |
| `get_run` / `list_runs` | read | Run status, results, error messages |
| `get_analysis` / `list_analyses` | read | Analysis status and results |
| `list_result_files` / `read_result_file` | read | Inspect raw output files (text, size-capped) |
| `find_or_create_parameter_set` | write | Idempotent parameter set creation |
| `create_runs` | write | Idempotent run creation ("up to N runs") |
| `create_analysis` | write | Run an analyzer on a finished run / parameter set |

A typical agent workflow:

1. `list_simulators` and `list_hosts` to learn what exists,
2. `find_or_create_parameter_set` → `create_runs` to submit jobs,
3. poll `get_parameter_set` (or `search_parameter_sets` for many) until runs finish — jobs are submitted asynchronously by the background workers, so results take a while,
4. inspect `get_run`, `read_result_file`, or aggregate with `include_average_results`,
5. `create_analysis` on the finished runs and poll `get_analysis`,
6. decide the next parameter sets and repeat.

All write tools are idempotent, so a retried tool call never duplicates parameter sets, runs, or analyses.

## Notes

- Validation errors are returned to the agent in a structured form including the expected format (e.g. the regexp a host parameter must match), so agents can self-correct.
- `read_result_file` reads text files only, at most 256 kB per call, with `offset_bytes` for paging through long logs.
- The server logs to stderr; stdout is reserved for the protocol.
