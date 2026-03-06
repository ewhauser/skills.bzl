#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "usage: $0 <staged_tree> <destination> <manifest>" >&2
  exit 1
fi

resolve_input_path() {
  local candidate="$1"
  local script_dir

  if [[ -e "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  if [[ -n "${RUNFILES_DIR:-}" && -e "${RUNFILES_DIR}/_main/${candidate}" ]]; then
    echo "${RUNFILES_DIR}/_main/${candidate}"
    return 0
  fi

  script_dir="$(cd "$(dirname "$0")" && pwd)"
  if [[ -e "${script_dir}.runfiles/_main/${candidate}" ]]; then
    echo "${script_dir}.runfiles/_main/${candidate}"
    return 0
  fi

  return 1
}

staged_tree="$(resolve_input_path "$1")"
destination_rel="$2"
manifest="$(resolve_input_path "$3")"
workspace_dir="${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}"
destination_dir="${workspace_dir}/${destination_rel}"
state_file="${destination_dir}/.skills_bzl_managed"

if [[ ! -d "${staged_tree}" ]]; then
  echo "staged skills tree not found: ${staged_tree}" >&2
  exit 1
fi

mkdir -p "${destination_dir}"

remove_skill_dir() {
  local skill="$1"
  [[ -z "${skill}" ]] && return 0
  if [[ -e "${destination_dir}/${skill}" ]]; then
    chmod -R u+rwX "${destination_dir}/${skill}" 2>/dev/null || true
    rm -rf "${destination_dir:?}/${skill:?}"
  fi
}

if [[ -f "${state_file}" ]]; then
  while IFS= read -r skill; do
    [[ -z "${skill}" ]] && continue
    remove_skill_dir "${skill}"
  done < "${state_file}"
fi

mapfile -t skills < <(grep -v '^$' "${manifest}" | LC_ALL=C sort)

for skill in "${skills[@]}"; do
  remove_skill_dir "${skill}"
done

for skill in "${skills[@]}"; do
  if [[ ! -d "${staged_tree}/${skill}" ]]; then
    echo "expected staged skill directory missing: ${staged_tree}/${skill}" >&2
    exit 1
  fi
  cp -R "${staged_tree}/${skill}" "${destination_dir}/${skill}"
  chmod -R u+rwX "${destination_dir}/${skill}" 2>/dev/null || true
done

printf "%s\n" "${skills[@]}" > "${state_file}"
