#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "usage: $0 <staged_tree> <destination> <manifest> <update_target>" >&2
  exit 1
fi

resolve_input_path() {
  local candidate="$1"
  local normalized="$1"
  local script_dir

  if [[ "${normalized}" == ./* ]]; then
    normalized="${normalized#./}"
  fi

  if [[ -n "${RUNFILES_DIR:-}" && -e "${RUNFILES_DIR}/_main/${normalized}" ]]; then
    candidate="${RUNFILES_DIR}/_main/${normalized}"
    if [[ -d "${candidate}" ]]; then
      candidate="$(cd "${candidate}" && pwd -P)"
    else
      candidate="$(cd "$(dirname "${candidate}")" && pwd -P)/$(basename "${candidate}")"
    fi
    echo "${candidate}"
    return 0
  fi

  script_dir="$(cd "$(dirname "$0")" && pwd)"
  if [[ -e "${script_dir}.runfiles/_main/${normalized}" ]]; then
    candidate="${script_dir}.runfiles/_main/${normalized}"
    if [[ -d "${candidate}" ]]; then
      candidate="$(cd "${candidate}" && pwd -P)"
    else
      candidate="$(cd "$(dirname "${candidate}")" && pwd -P)/$(basename "${candidate}")"
    fi
    echo "${candidate}"
    return 0
  fi

  if [[ -e "${candidate}" ]]; then
    if [[ -d "${candidate}" ]]; then
      candidate="$(cd "${candidate}" && pwd -P)"
    else
      candidate="$(cd "$(dirname "${candidate}")" && pwd -P)/$(basename "${candidate}")"
    fi
    echo "${candidate}"
    return 0
  fi

  return 1
}

staged_tree="$(resolve_input_path "$1")"
destination_rel="$2"
manifest="$(resolve_input_path "$3")"
update_target="$4"
if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  workspace_dir="${BUILD_WORKSPACE_DIRECTORY}"
else
  echo "BUILD_WORKSPACE_DIRECTORY is not set; skipping sync validation under bazel test." >&2
  exit 0
fi
destination_dir="${workspace_dir}/${destination_rel}"

resolve_staged_skill_dir() {
  local skill="$1"
  local candidate=""

  if [[ -d "${staged_tree}/${skill}" ]]; then
    echo "${staged_tree}/${skill}"
    return 0
  fi

  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    if [[ -n "${candidate}" ]]; then
      echo "multiple staged directories found for skill '${skill}'" >&2
      return 1
    fi
    candidate="${path}"
  done < <(find "${staged_tree}" -type d -name "${skill}" | LC_ALL=C sort)

  if [[ -z "${candidate}" ]]; then
    return 1
  fi

  echo "${candidate}"
}

if [[ ! -d "${destination_dir}" ]]; then
  echo "${destination_rel} is missing. Run 'bazel run ${update_target}' to create it." >&2
  exit 1
fi
expected="$(mktemp)"
trap 'rm -f "${expected}"' EXIT

grep -v '^$' "${manifest}" | LC_ALL=C sort > "${expected}"

while IFS= read -r skill; do
  [[ -z "${skill}" ]] && continue
  if [[ ! -d "${destination_dir}/${skill}" ]]; then
    echo "Managed skill '${skill}' is missing. Run 'bazel run ${update_target}'." >&2
    exit 1
  fi
  staged_skill_dir="$(resolve_staged_skill_dir "${skill}")" || {
    echo "Managed skill '${skill}' is missing from the staged tree. Run 'bazel run ${update_target}'." >&2
    exit 1
  }
  if ! diff -ru "${staged_skill_dir}" "${destination_dir}/${skill}" >/dev/null; then
    echo "Managed skill '${skill}' is out of date. Run 'bazel run ${update_target}'." >&2
    diff -ru "${staged_skill_dir}" "${destination_dir}/${skill}" >&2 || true
    exit 1
  fi
done < "${expected}"
