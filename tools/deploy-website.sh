#!/usr/bin/env bash
# tools/deploy-website.sh: publish website/ under the site's S3 prefix.
#
#   bash tools/deploy-website.sh          checks, then a dry run of the upload
#   bash tools/deploy-website.sh --check  checks only (no AWS needed)
#   bash tools/deploy-website.sh --go     checks, upload, CloudFront invalidation
#
# The site workflow (.github/workflows/site.yml) runs --go on every push to
# main that touches website/. It needs SITE_BUCKET and SITE_DISTRIBUTION in the
# environment; it only ever writes under s3://$SITE_BUCKET/halogen/ (sync
# --delete is scoped to that prefix).
set -euo pipefail

PREFIX="halogen"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/website"
MODE="${1:-dry}"

[ -f "$SRC/index.html" ] || { echo "no site at $SRC" >&2; exit 1; }

# Public text rules the docs follow too: no em-dash or en-dash, and no
# request to another host at runtime (plain links to our own pages only).
fail=0
pages=("$SRC"/*.html "$SRC"/*.css)
if grep -n -e "$(printf '\342\200\224')" -e "$(printf '\342\200\223')" "${pages[@]}"; then
  echo "FAIL: em-dash or en-dash in the site" >&2; fail=1
fi
ext=$(grep -n -o -E '(src|href)="https?://[^"]+"|url\(["'\'']?https?://[^)]+' "${pages[@]}" \
  | grep -v -E 'href="https://(peonist-ai\.github\.io/halogen-flash-server|github\.com/peonist-ai/halogen-flash-server|discord\.gg/bcm6QknaV6)' || true)
if [ -n "$ext" ]; then
  echo "$ext"; echo "FAIL: a link or asset on another host" >&2; fail=1
fi
[ "$fail" = 0 ] || exit 1
echo "checks: OK"
[ "$MODE" = "--check" ] && exit 0

: "${SITE_BUCKET:?set SITE_BUCKET}"
: "${SITE_DISTRIBUTION:?set SITE_DISTRIBUTION}"
command -v aws >/dev/null || { echo "aws CLI not found" >&2; exit 1; }

DEST="s3://$SITE_BUCKET/$PREFIX/"
EXCL=(--exclude "SOURCES.md" --exclude ".*" --exclude "*/.*")
DRY=()
[ "$MODE" = "--go" ] || DRY=(--dryrun)

# HTML: short cache, so an edit shows within minutes even before invalidation.
aws s3 sync "$SRC/" "$DEST" ${DRY[@]+"${DRY[@]}"} --delete "${EXCL[@]}" \
  --exclude "*" --include "*.html" \
  --cache-control "public, max-age=300" --content-type "text/html; charset=utf-8"
# Fonts get an explicit type (the CLI's guess for .ttf varies by platform).
aws s3 sync "$SRC/" "$DEST" ${DRY[@]+"${DRY[@]}"} "${EXCL[@]}" \
  --exclude "*" --include "*.ttf" \
  --cache-control "public, max-age=86400" --content-type "font/ttf"
# Everything else (css, images, the font licence): one day.
aws s3 sync "$SRC/" "$DEST" ${DRY[@]+"${DRY[@]}"} --delete "${EXCL[@]}" \
  --exclude "*.html" --exclude "*.ttf" \
  --cache-control "public, max-age=86400"

if [ "$MODE" = "--go" ]; then
  aws cloudfront create-invalidation --distribution-id "$SITE_DISTRIBUTION" \
    --paths "/$PREFIX" "/$PREFIX/*" --query 'Invalidation.Id' --output text
  echo "uploaded to $DEST; invalidation sent"
else
  echo "dry run only; --go uploads"
fi
