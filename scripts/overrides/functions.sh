function findreal {
    local cmd_to_find="${1}"
    local me=$( which "${cmd_to_find}" )
    local real=""
    while read real; do
        if ! [[ "${me}" == "${real}" ]]; then
            echo "${real}"
            return
        fi
    done < <( type -all -path "${cmd_to_find}" )
}

### Subject to change
export SINGULARITY_BINARY_PATH=/opt/singularity/bin/singularity