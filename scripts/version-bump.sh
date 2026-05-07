#!/bin/sh
# Version bump script — single source of truth for all cyim-lsp version references.
#
# Usage:
#   sh scripts/version-bump.sh 1.1.0          # bump VERSION + regenerate everything
#   sh scripts/version-bump.sh "$(cat VERSION)" # regenerate without bumping
#
# Mirrors cyim's scripts/version-bump.sh shape. The standalone
# CLI banner in src/main.cyr reads from the generated
# src/version_str.cyr instead of a hardcoded literal so version
# drift between VERSION and the source can never happen.
# cyrius.cyml's `version = "${file:VERSION}"` resolves at build
# time; CHANGELOG header still gets inserted by this script.

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Current: $(cat VERSION)"
    exit 1
fi

NEW="$1"
OLD=$(cat VERSION | tr -d '[:space:]')

# 1. Regenerate src/version_str.cyr unconditionally. Same-version
#    invocations (`sh scripts/version-bump.sh "$(cat VERSION)"`)
#    are the documented "regenerate without bumping" path; useful
#    if you suspect drift or want to refresh after rename.
LEN_LSP=$((${#NEW} + 10))   # "cyim-lsp " + version + "\n"
cat > src/version_str.cyr <<EOF
# src/version_str.cyr — AUTO-GENERATED from \`VERSION\` by
# \`scripts/version-bump.sh\`. Do NOT edit by hand; the next bump
# will overwrite. To regenerate without bumping, run:
#
#   sh scripts/version-bump.sh "\$(cat VERSION)"
#
# Mirrors cyim's pattern (cyim/src/version_str.cyr +
# cyim/scripts/version-bump.sh). The standalone CLI banner in
# src/main.cyr reads these vars instead of a hardcoded literal,
# so the version string can never drift from VERSION.
# cyrius.cyml's \`version = "\${file:VERSION}"\` resolves
# separately at build time.

var _VERSION_STR_LSP = "cyim-lsp $NEW\n";
var _VERSION_LEN_LSP = $LEN_LSP;
EOF

if [ "$NEW" = "$OLD" ]; then
    echo "Already at $OLD (regenerated src/version_str.cyr)"
    exit 0
fi

# 2. VERSION file (source of truth). cyrius.cyml resolves
#    `${file:VERSION}` so it doesn't need its own touch.
echo "$NEW" > VERSION

# 3. CHANGELOG.md — insert new version header after [Unreleased].
#    Anchored regex matches ONLY the literal "## [Unreleased]"
#    header line, not body text quoting it (cyim 5.8.49 lesson).
if ! grep -q "## \[$NEW\]" CHANGELOG.md 2>/dev/null; then
    sed -i "/^## \[Unreleased\]$/a\\
\\
## [$NEW] — $(date +%Y-%m-%d)" CHANGELOG.md 2>/dev/null || true
fi

echo "$OLD -> $NEW"
echo ""
echo "Updated:"
echo "  VERSION"
echo "  src/version_str.cyr (regenerated)"
echo "  CHANGELOG.md (new header inserted)"
echo ""
echo "Still manual:"
echo "  - CHANGELOG.md body (Added/Changed/Removed sections)"
echo "  - docs/development/state.md"
echo "  - docs/development/roadmap.md (if milestone landed)"
echo "  - dist/cyim-lsp.cyr (run 'cyrius distlib' after distfile-affecting changes)"
