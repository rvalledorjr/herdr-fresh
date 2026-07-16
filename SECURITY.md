# Security

## Reporting a vulnerability

Please open a private report via GitHub's
[Security Advisories](https://github.com/rvalledorjr/herdr-fresh/security/advisories) for this
repo rather than a public issue, if the problem is exploitable against someone else's install.
For anything else (config trust-model questions, hardening suggestions), a regular issue is
fine.

## Trust model

herdr-fresh is a thin launcher around [Fresh](https://getfresh.dev). It does not add its own
sandboxing or content trust logic beyond what's described below — for anything editor-side
(opening a file, running LSP, Git review, remote SSH edits) it leans entirely on **Fresh's own
Workspace Trust model**. If you're opening a repo you don't trust, treat it the same way you
would opening it directly in Fresh: check Fresh's own trust prompts/config before running its
LSP servers, plugins, or auto-executing project settings against untrusted content. herdr-fresh
does not intercept or override any of that.

## What herdr-fresh itself touches

- **`config.toml`** — read-only input, `fresh_bin`/`fresh_args`/daemon-naming overrides only.
  Loaded **exclusively** from the herdr-provided `$HERDR_PLUGIN_CONFIG_DIR` (or the
  `$XDG_CONFIG_HOME`/`$HOME` fallback for standalone use) — **never** from a repo's own working
  directory. This is intentional: an untrusted repo you `cd` into or open via herdr cannot smuggle
  in its own `fresh_bin` override to get herdr-fresh to launch an arbitrary binary. See
  `scripts/common.sh`'s `_config_path` (absolute-path guard) and
  [docs/configuration.md](docs/configuration.md).
- **`git config core.editor`** — only ever written by
  `scripts/suggest-editor-integration.sh`, which is never invoked automatically. It always prints
  the exact command it's about to run and asks for confirmation before writing (`--yes` to skip,
  for scripted/non-interactive use only). See
  [docs/editor-integration.md](docs/editor-integration.md).
- **Daemon names / pane labels** — derived from a herdr workspace id or a hash of the resolved
  cwd (see PLAN.md §4.2). No untrusted input is interpolated into a shell command unquoted;
  `fresh_args` from config.toml is the one exception worth knowing about (see below).

## Known limitation: `fresh_args` is not shell-escaped

`config.toml`'s `fresh_args` array is space-joined and passed through to `fresh -a <daemon>` as
literal words, with no shell quoting/escaping applied (see
[docs/configuration.md](docs/configuration.md)). Since `config.toml` can only ever come from a
trusted, herdr-managed config directory (never a repo's cwd — see above), this is a
configuration footgun (avoid values containing spaces) rather than an injection vector from
untrusted repo content.

## Build-time installer trust

`scripts/install.sh`/`install.ps1` (the `[[build]]` step) pipe the official Fresh installer
script from `getfresh.dev`'s GitHub source over HTTPS when `fresh` isn't already present. This
is the same trust boundary as installing Fresh yourself by hand — herdr-fresh doesn't vendor or
modify that script. If you don't want a plugin install to run that installer automatically,
install `fresh` yourself first (the build step no-ops once `fresh` is found on `PATH`).
