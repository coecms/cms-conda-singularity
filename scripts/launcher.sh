#!/usr/bin/env bash

function in_array() {
    ### Assumes first n-1 args are an array and final arg is the string to search for
    ### Necessary because [[ libab =~ liba ]] returns true
    declare -a allargs=( "$@" )
    finalarg=${allargs[$(( ${#allargs[@]} - 1 ))]}
    for (( j=0; j<$(( ${#allargs[@]} - 2 )); j++ )); do
        [[ "${allargs[$j]}" == "${finalarg}" ]] && return 0
    done
    return 1
}

script=$( realpath -s "${0}" )
wrapper_bin=$( dirname "${script}" )
### From time to time we need to manually specify an overlay filesystem, handle that here:
if [[ "${1}" == "-o" ]]; then
    export CONTAINER_OVERLAY_PATH="${2}"
    shift 2
fi
### Allow invoking launcher directly with arbitrary commands
if [[ "${script}" == "${LAUNCHER_SCRIPT}" ]]; then
    ### Assume "$1" and onwards is the command to run
    cmd_to_run=( "$@" )
else
    cmd_to_run=( $( basename "${0}" ) )
    cmd_to_run+=( "$@" )
fi
### Short circuit detection
### In some cases (e.g. mpi processes launched from orterun), launcher will be invoked from
### within the container. The tell-tale sign for this is if /opt/singularity is missing.
### Assume if /opt/singularity is missing, we're being invoked from the container and just
### run the requested command
if ! [[ -d /opt/singularity ]]; then
    exec "${cmd_to_run[@]}"
fi

### Refuse to launch ssh from the container, and instead ssh then invoke launcher
if [[ "${cmd_to_run[0]: -3}" == "ssh" ]]; then
    echo "${cmd_to_run[@]}"
    ### Handling this properly will take some thought, we need to pretty much parse
    ### options as ssh would and figure out a host name and whether or not there is a 
    ### command to run ahead of time.
    exec /bin/ssh "${cmd_to_run[@]:1}"
fi


export SINGULARITYENV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
declare -a singularity_default_path=( '/usr/local/sbin' '/usr/local/bin' '/usr/sbin' '/usr/bin' '/sbin' '/bin' )

while IFS= read -r -d: i; do
    in_array "${singularity_default_path[@]}" "${i}" && continue
    [[ "${i}" == "/opt/singularity/bin" ]] && continue
    [[ "${i}" == "${wrapper_bin}" ]] && continue
    module append-path SINGULARITYENV_PREPEND_PATH "${i}"
done<<<"${PATH%:}:"

overlay_args=""
while IFS= read -r -d: i; do
    overlay_args="${overlay_args}--overlay=${i} "
done<<<"${CONTAINER_OVERLAY_PATH%:}:"

module load singularity

singularity -s exec --bind /etc,/half-root,/local,/ram,/run,/system,/usr,/var/lib/sss,/var/run/munge ${overlay_args} /g/data/v45/dr4292/singularity/test.sif "${cmd_to_run[@]}"
