#!/bin/sh
# The website serves the agent skill at /skill.md. skills/silhouette/SKILL.md is the source;
# run this after changing it (CI fails if the two differ).
set -e
cd "$(dirname "$0")/.."
cp skills/silhouette/SKILL.md docs/skill.md
