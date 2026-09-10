#!/usr/bin/env bash
# Sourced by every bin/ script. Loads the core in dependency order.
set -euo pipefail
_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=out.sh
source "$_lib/out.sh"; source "$_lib/config.sh"; source "$_lib/repos.sh"
source "$_lib/adapter.sh"; source "$_lib/classify.sh"; source "$_lib/inventory.sh"; source "$_lib/notes.sh"
load_adapter
