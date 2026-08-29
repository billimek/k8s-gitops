#!/usr/bin/env -S just --justfile

set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

export K8S_DIR := justfile_dir() / "kubernetes"
export SETUP_DIR := justfile_dir() / "setup"
export KUBECONFIG := justfile_dir() / "kubeconfig"
export MINIJINJA_CONFIG_FILE := justfile_dir() / ".justfiles/.minijinja.toml"
export TALOSCONFIG := justfile_dir() / "setup/talos/talosconfig"

[private]
default:
    just --list --list-submodules

[group: 'K8s']
mod k8s ".justfiles/k8s.just"

[group: 'Bootstrap']
mod bootstrap ".justfiles/bootstrap.just"

[group: 'Kopiur']
mod kopiur ".justfiles/kopiur.just"

[group: 'Talos']
mod talos ".justfiles/talos.just"

# Emit a leveled, structured log line (used by all recipes for status/error output)
[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

# Render a minijinja template and inject 1Password references
[private]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | op inject
