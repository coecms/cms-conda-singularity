#!/usr/bin/env bash
script=$( realpath -s "${0}" )
overrides_bin=$( dirname "${script}" )
source "${overrides_bin}"/functions.sh

### pbs_tmrsh [-n][-l username] host [-n][-l username] command
### Needs to become
### pbs_tmrsh [-n][-l username] host [-n][-l username] launcher.sh -o $CONTAINER_OVERLAY_PATH command

declare -a stored_args=()
seen_host=""

while true; do
    case "${1}" in
        -n )
            stored_args+=( "${1}" )
            shift
            ;;
        -l )
            stored_args+=( "${1}", "${2}" )
            shift 2
            ;;
        -l* )
            stored_args+=( "${1}" )
            shift
            ;;
        * )
            [[ "${seen_host}" ]] && break
            seen_host=1
            stored_args+=( "${1}" )
            shift
    esac
done

echo $( findreal pbs_tmrsh ) "${stored_args[@]}" $( which launcher.sh ) -s "${SINGULARITY_BINARY_PATH}" -o "${CONTAINER_OVERLAY_PATH}" -p "${PATH}" "${@}"
exec $( findreal pbs_tmrsh ) "${stored_args[@]}" $( which launcher.sh ) -s "${SINGULARITY_BINARY_PATH}" -o "${CONTAINER_OVERLAY_PATH}" -p "${PATH}" "${@}"