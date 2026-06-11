#!/usr/bin/env bash
# Fetch the authoritative Google Slides API discovery document and vendor it as the pinned SSOT.
#
# The discovery document (https://slides.googleapis.com/$discovery/rest?version=v1) is the
# machine-readable source of truth for every type, enum, and field-level prose constraint the
# package mirrors. We vendor it (not fetch at runtime) so the build is hermetic and the schema
# can never silently drift from under us — drift is surfaced by SpecProvenanceTests, which pins
# the `revision` and the exact prose sentences the validator depends on.
#
# Usage:  scripts/fetch-discovery.sh
# After running, re-run `swift test`. If SpecProvenanceTests fails, Google changed the spec:
# review the diff, update GSlidesSpec.pinnedRevision and (if prose changed) the pinned sentences
# and constraints-catalog.yaml, then re-derive any affected validator rules.
set -euo pipefail

DISCOVERY_URL="https://slides.googleapis.com/\$discovery/rest?version=v1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$SCRIPT_DIR/../Sources/GSlidesSchema/Resources/Spec/slides-api-discovery-v1.json"

echo "Fetching $DISCOVERY_URL"
# Pretty-print so the vendored file diffs cleanly in review.
curl -fsSL "$DISCOVERY_URL" | python3 -m json.tool --no-ensure-ascii > "$DEST"

REVISION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["revision"])' "$DEST")"
echo "Wrote $DEST"
echo "revision: $REVISION"
echo
echo "Next: update GSlidesSpec.pinnedRevision to \"$REVISION\" if it changed, then run: swift test"
