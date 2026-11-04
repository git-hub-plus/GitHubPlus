#!/usr/bin/env bash
# Runs the suite in two passes. Widget tests drive real git through the UI and
# time out when the core tests flood the machine with git processes at the
# same time, so they run after the core tests with less parallelism.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter test test/core test/l10n "$@"
flutter test --concurrency=2 test/ui test/features "$@"
