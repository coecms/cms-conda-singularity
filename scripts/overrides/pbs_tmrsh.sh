#!/usr/bin/env bash
script=$( realpath "${0}" )
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

real_launcher=$( type -p launcher.sh )

### Pretty much have to re-insert the entire relevant environment for this to work
exec $( findreal pbs_tmrsh ) "${stored_args[@]}" "${real_launcher}" --cms_singularity_singularity_path "${SINGULARITY_BINARY_PATH}" --cms_singularity_launcher_override "${real_launcher}" --cms_singularity_overlay_path "${CONTAINER_OVERLAY_PATH}" --cms_singularity_in_container_path "${PATH}" "${@}"