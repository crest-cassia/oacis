---
layout: default
title: "MCP Server"
lang: en
next_page: api
---

# MCP Server for AI agents

---

OACIS ships an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server, `bin/oacis_mcp`, which lets AI agents such as Claude submit and monitor simulation jobs.
An agent connected to this server can explore parameter spaces autonomously: create parameter sets, submit runs, poll their status, read result files, and trigger analyzers.

The server speaks JSON-RPC over stdio and accesses the OACIS database in-process, exactly like the [Ruby API]({{ site.baseurl }}/{{ page.lang }}/api.html). Jobs created through it are picked up and submitted to remote hosts by the ordinary OACIS background workers.

MCP is the recommended interface for interactive, agent-driven use. For unattended long-running workflows — for example an optimization loop that keeps submitting jobs for days — a script using the [Ruby API]({{ site.baseurl }}/{{ page.lang }}/api.html) and [OACIS watcher]({{ site.baseurl }}/{{ page.lang }}/api_watcher.html) is the better tool. The two combine well: you can ask an agent to write such a script for you.

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

Running multiple OACIS docker instances on one machine works fine with MCP: the server is stdio-only and opens no network port, and each instance's `oacis_mcp.sh` (in the oacis_docker checkout) connects to the container of its own docker compose project. Just register each instance under a distinct server name, and pick names that make clear which instance the agent is writing to:

```shell
claude mcp add oacis_proj_a -- /path/to/proj_a/oacis_docker/oacis_mcp.sh
claude mcp add oacis_proj_b -- /path/to/proj_b/oacis_docker/oacis_mcp.sh
```

## Direct access to result files

`get_run`, `get_analysis`, `get_parameter_set`, and `list_result_files` report the result directory of the record as `dir` (or `base_dir`). When the agent runs on a machine where that path is accessible — the same machine as OACIS, or a Docker host with the Result directory bind-mounted — it should read the output files there directly with its own file tools. This is the preferred way to consume results: unlike `read_result_file`, it has no size cap and works for binary files such as plot images, so a multimodal agent can look at the plots an analyzer produced.

When OACIS runs in a container and the agent on the host, set `OACIS_MCP_DIR_MAP="<server_prefix>=<client_prefix>"` in the server's environment and all reported paths are rewritten accordingly. `oacis_docker`'s `oacis_mcp.sh` sets this automatically, mapping the container's Result directory to the bind-mounted `Result/` on the host.

`read_result_file` remains available as a fallback for setups where the result directory is not reachable from the agent (e.g. OACIS on a remote server).

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
4. inspect `get_run` and read the files under its `dir` directly (or `read_result_file` remotely), or aggregate with `include_average_results`,
5. `create_analysis` on the finished runs and poll `get_analysis`,
6. decide the next parameter sets and repeat.

All write tools are idempotent, so a retried tool call never duplicates parameter sets, runs, or analyses.

## Notes

- Validation errors are returned to the agent in a structured form including the expected format (e.g. the regexp a host parameter must match), so agents can self-correct.
- `read_result_file` reads text files only, at most 256 kB per call, with `offset_bytes` for paging through long logs.
- The server logs to stderr; stdout is reserved for the protocol.
