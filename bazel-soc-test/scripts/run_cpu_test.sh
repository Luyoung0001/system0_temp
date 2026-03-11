#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <sim_bin> <soc_image_bin> [max_cycles]" >&2
  exit 1
fi

SIM_BIN="$1"
SOC_IMAGE_BIN="$2"
MAX_CYCLES="${3:-2000000}"

"${SIM_BIN}" --image "${SOC_IMAGE_BIN}" --max-cycles "${MAX_CYCLES}"
