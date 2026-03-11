#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <sim_bin> <ref_so> <image_bin>" >&2
  exit 1
fi

SIM_BIN="$1"
REF_SO="$2"
IMAGE_BIN="$3"

"$SIM_BIN" --diff --ref "$REF_SO" --image "$IMAGE_BIN"
