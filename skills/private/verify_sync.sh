#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "usage: $0 <staged_tree> <destination> <manifest> <update_target>" >&2
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
update_target="$4"
workspace_dir="${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}"
destination_dir="${workspace_dir}/${destination_rel}"
state_file="${destination_dir}/.skills_bzl_managed"

if [[ ! -d "${destination_dir}" ]]; then
  echo "${destination_rel} is missing. Run 'bazel run ${update_target}' to create it." >&2
  exit 1
fi

if [[ ! -f "${state_file}" ]]; then
  echo "${state_file} is missing. Run 'bazel run ${update_target}' to sync managed skills." >&2
  exit 1
fi

expected="$(mktemp)"
actual="$(mktemp)"
trap 'rm -f "${expected}" "${actual}"' EXIT

grep -v '^$' "${manifest}" | LC_ALL=C sort > "${expected}"
grep -v '^$' "${state_file}" | LC_ALL=C sort > "${actual}"

if ! diff -u "${expected}" "${actual}" >/dev/null; then
  echo "Managed skill manifest is out of date. Run 'bazel run ${update_target}'." >&2
  diff -u "${expected}" "${actual}" >&2 || true
  exit 1
fi

while IFS= read -r skill; do
  [[ -z "${skill}" ]] && continue
  if [[ ! -d "${destination_dir}/${skill}" ]]; then
    echo "Managed skill '${skill}' is missing. Run 'bazel run ${update_target}'." >&2
    exit 1
  fi
  if ! diff -ru "${staged_tree}/${skill}" "${destination_dir}/${skill}" >/dev/null; then
    echo "Managed skill '${skill}' is out of date. Run 'bazel run ${update_target}'." >&2
    diff -ru "${staged_tree}/${skill}" "${destination_dir}/${skill}" >&2 || true
    exit 1
  fi
done < "${expected}"
