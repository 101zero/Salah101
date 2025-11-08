#!/usr/bin/env bash
set -euo pipefail

TARGETS=${TARGETS_PATH:-/data/subdomains.txt}
OUTPUT=${OUTPUT_PATH:-/data/results.json}
PROVIDER=${PROVIDER_PATH:-/secrets/provider.yaml}

echo "[ℹ] start: $(date)"
echo "[ℹ] TARGETS=$TARGETS"
echo "[ℹ] OUTPUT=$OUTPUT"
echo "[ℹ] PROVIDER=$PROVIDER"

if [ ! -f "$TARGETS" ]; then
  echo "[!] targets not found at $TARGETS"
  exit 2
fi

# run nuclei (adjust template flags as needed)
nuclei -l "$TARGETS" -s high,critical -silent -o "$OUTPUT" || true

# notify if results exist and provider file exists
if [ -s "$OUTPUT" ] && [ -f "$PROVIDER" ]; then
  echo "[+] sending notify..."
  notify -pc "$PROVIDER" -input "$OUTPUT" || echo "[!] notify failed"
else
  echo "[ℹ] no results or provider missing, skipping notify."
fi

echo "[ℹ] done: $(date)"
exit 0
