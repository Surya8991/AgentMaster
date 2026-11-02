# Core runtime readiness: 2026-11-02

The two missing command-line prerequisites identified by the routing evaluation
are installed and functionally verified on the Windows development machine:

| Component | Version | Verification |
|---|---|---|
| DAP CLI | v0.4.2 | Hit a Python breakpoint at line 2, inspected `value = 41`, resumed, observed `42`, and stopped the session |
| Python debugpy | 1.8.22 | Used by the DAP probe with an explicit Python interpreter |
| agent-browser | 0.41.1 | Opened a temporary local HTML page in an isolated headless session, checked its title and interactive button, then closed the session |
| Managed Chrome | 156.0.8078.80 | Launched successfully by agent-browser |

The default local availability checker now reports **29 available checks, zero
missing checks, and 18 unknown checks**. These counts include repeated requirements
and are not a count of unique skills. Executable presence checks alone do not
prove runtime health; the functional probes above provide separate evidence.

## Windows debugger invocation

Use the [official Windows DAP release](https://github.com/AlmogBaku/debug-skill/releases/tag/v0.4.2)
when Go is not installed. The downloaded `dap-windows-amd64.exe` was verified
against its published SHA-256:

```text
13004bc7ea46eba7d84363af99e59d4b55d0e1b7d8a65bc29b4cc8c739d0adee
```

It was placed as `dap.exe` in the existing user CLI directory (`%APPDATA%/npm`),
already on PATH. No system PATH change or Go installation was needed.

DAP v0.4.2 splits breakpoint specifications at colons, so an absolute Windows
drive path such as `C:\project\example.py:2` fails parsing. Run from the program's
directory and use a **relative breakpoint path**. Select Python explicitly because
the tool otherwise defaults to `python3`, which may not be the intended Windows
interpreter. The debugpy executable does not need to be on PATH when launched as
a module through this interpreter.

```powershell
Push-Location C:\path\to\project
try {
    dap debug example.py --python (Get-Command python).Source --break example.py:2 --session my-task --json
    dap eval value --session my-task --json
    dap continue --session my-task
} finally {
    dap stop --session my-task
    Pop-Location
}
```

The installed backend covers Python. Go, Node, Rust and C/C++ debugging still
require their respective backends when those languages are used; this probe does
not assert they are installed or healthy.

## Browser invocation

Installation followed the [upstream agent-browser guide](https://github.com/vercel-labs/agent-browser):

```powershell
npm install --global agent-browser@0.41.1
agent-browser install
```

Use a unique `--session` for each task and close that session afterward. The
readiness test used a temporary local page and a new managed browser; it did not
connect to the user's existing browser profile or tabs.

## Explicitly optional / unverified

The user chose **Keep optional; finish core readiness** for reverse-engineering
setup. REA/IDA MCP configuration was left untouched, and no native analysis engines
or licensed IDA installation were added. Plugin inventories and MCP runtime
health remain unknown, not failed and not verified. Namespaced skills in the
routing table must be resolved against the current host's actual capabilities;
an installed skill file alone is not evidence that its tools are connected.
