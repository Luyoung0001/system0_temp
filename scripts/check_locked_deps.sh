#!/usr/bin/env bash
set -euo pipefail

ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
DEPS=("CL3" "ysyxSoC")

count_non_empty_lines() {
  awk 'NF { c += 1 } END { print c + 0 }'
}

print_block() {
  local title="$1"
  local body="$2"
  if [[ -z "${body}" ]]; then
    return
  fi
  echo "       ${title}:"
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    echo "         ${line}"
  done <<<"${body}"
}

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "[deps] ERROR: not in a git repository"
  exit 2
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "${ROOT}"

fail=0
for dep in "${DEPS[@]}"; do
  echo "[deps] CHECK: ${dep}"
  submodule_url="$(git config -f .gitmodules --get "submodule.${dep}.url" || true)"
  if [[ -z "${submodule_url}" ]]; then
    echo "[deps] ERROR: ${dep} has no url in .gitmodules"
    fail=1
    continue
  fi
  echo "       url     : ${submodule_url}"

  tree_line="$(git ls-tree -d HEAD -- "${dep}" || true)"
  if [[ -z "${tree_line}" ]]; then
    echo "[deps] ERROR: ${dep} is not tracked in HEAD"
    fail=1
    continue
  fi

  mode="$(awk '{print $1}' <<<"${tree_line}")"
  type="$(awk '{print $2}' <<<"${tree_line}")"
  expected="$(awk '{print $3}' <<<"${tree_line}")"
  if [[ "${mode}" != "160000" || "${type}" != "commit" ]]; then
    echo "[deps] ERROR: ${dep} is not a locked gitlink in HEAD (mode=${mode}, type=${type})"
    fail=1
    continue
  fi

  if ! git -C "${dep}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[deps] ERROR: ${dep} is missing or not a git repository"
    fail=1
    continue
  fi

  actual="$(git -C "${dep}" rev-parse HEAD)"
  echo "       expected: ${expected}"
  echo "       actual  : ${actual}"

  dep_fail=0
  if [[ "${actual}" != "${expected}" ]]; then
    echo "[deps] ERROR: ${dep} HEAD mismatch"
    echo "       run: git -C ${dep} checkout ${expected}"
    dep_fail=1
  fi

  staged="$(git -C "${dep}" diff --name-status --cached)"
  unstaged="$(git -C "${dep}" diff --name-status)"
  untracked="$(git -C "${dep}" ls-files --others --exclude-standard)"

  staged_count="$(count_non_empty_lines <<<"${staged}")"
  unstaged_count="$(count_non_empty_lines <<<"${unstaged}")"
  untracked_count="$(count_non_empty_lines <<<"${untracked}")"
  dirty_count=$((staged_count + unstaged_count + untracked_count))

  if (( dirty_count > 0 )); then
    reasons=()
    (( staged_count > 0 )) && reasons+=("staged=${staged_count}")
    (( unstaged_count > 0 )) && reasons+=("unstaged=${unstaged_count}")
    (( untracked_count > 0 )) && reasons+=("untracked=${untracked_count}")
    echo "       dirty reason: ${reasons[*]}"
    print_block "staged changes" "${staged}"
    print_block "unstaged changes" "${unstaged}"
    print_block "untracked files" "${untracked}"

    if [[ "${ALLOW_DIRTY}" == "1" ]]; then
      echo "[deps] WARN : ${dep} is dirty, allowed by ALLOW_DIRTY=1"
    else
      echo "[deps] ERROR: ${dep} is dirty"
      echo "       set ALLOW_DIRTY=1 to bypass in local development"
      dep_fail=1
    fi
  else
    echo "[deps] OK   : ${dep} is clean"
  fi

  if (( dep_fail != 0 )); then
    fail=1
  fi
done

if [[ "${fail}" != "0" ]]; then
  exit 2
fi

echo "[deps] locked dependency check passed"
