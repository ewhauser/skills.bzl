#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "usage: $0 <staged_tree> <destination> <manifest>" >&2
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
workspace_dir="${BUILD_WORKSPACE_DIRECTORY:-$(pwd)}"
destination_dir="${workspace_dir}/${destination_rel}"

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

declare -a skills=()
while IFS= read -r skill; do
  [[ -z "${skill}" ]] && continue
  skills+=("${skill}")
done < <(grep -v '^$' "${manifest}" | LC_ALL=C sort)

for skill in "${skills[@]}"; do
  remove_skill_dir "${skill}"
done

for skill in "${skills[@]}"; do
  skill_src="$(resolve_staged_skill_dir "${skill}")" || {
    echo "expected staged skill directory missing for skill '${skill}' under ${staged_tree}" >&2
    exit 1
  }
  cp -R "${skill_src}" "${destination_dir}/${skill}"
  chmod -R u+rwX "${destination_dir}/${skill}" 2>/dev/null || true
done
