#!/usr/bin/env bash
# Sourced by lib/release-common.sh; defines output helpers only.

err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
info() { printf '%s\n' "$*"; }
die()  { err "$*"; exit 1; }

now_stamp() { date '+%Y-%m-%d %H:%M %z'; }
today()     { date '+%Y-%m-%d'; }
