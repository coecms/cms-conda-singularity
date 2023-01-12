#!/usr/bin/env bash

[[ "${SCRIPT_DIR}" ]] && cd "${SCRIPT_DIR}"

source install_config.sh
source functions.sh

### Derived temp file locations
export OVERLAY_BASE="${CONDA_TEMP_PATH}"/overlay/
export CONDA_OUTER_BASE="${OVERLAY_BASE}"/"${CONDA_BASE#/*/}"
export CONDA_SCRIPT_PATH="${CONDA_BASE}"/scripts
export CONDA_MODULE_PATH="${CONDA_BASE}"/modules

### Derived installation path
export CONDA_INSTALLATION_PATH="${CONDA_INSTALLATION_PATH:-$CONDA_BASE/apps/miniconda3}"

function inner() {

    mkdir -p "${CONDA_INSTALLATION_PATH%/*}"
    bash Miniconda3-py39_4.12.0-Linux-x86_64.sh -b -p "${CONDA_INSTALLATION_PATH}"

    . "${CONDA_INSTALLATION_PATH}"/etc/profile.d/conda.sh
    conda install mamba -y

    mkdir -p "${CONDA_SCRIPT_PATH}"/overrides
    cp "${SCRIPT_DIR}"/launcher{,_conf}.sh "${CONDA_SCRIPT_PATH}"
    cp "${SCRIPT_DIR}"/overrides/* "${CONDA_SCRIPT_PATH}"/overrides

    mkdir -p "${CONDA_MODULE_PATH}"/conda
    cp "${SCRIPT_DIR}"/condaenv.sh "${CONDA_MODULE_PATH}"/conda
    cp "${SCRIPT_DIR}"/../modules/common_v3 "${CONDA_MODULE_PATH}"/conda/.common_v3
    cp "${SCRIPT_DIR}"/../modules/are       "${CONDA_MODULE_PATH}"/conda/are

    conda clean -a -f -y

}

if [[ "${1}" == '--inner' ]]; then
    inner
    exit
fi

wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.12.0-Linux-x86_64.sh

mkdir "${PBS_JOBFS}"/overlay
/opt/singularity/bin/singularity -s exec --bind /etc,/half-root,/local,/ram,/run,/system,/usr,/var/lib/sss,/var/run/munge,/var/lib/rpm,"${OVERLAY_BASE}":/g "${CONTAINER_PATH}" $( realpath $0 ) --inner

### Copy in container
cp "${CONTAINER_PATH}" "${CONDA_OUTER_BASE}"/apps/miniconda3/etc/
### Set permissions
set_apps_perms "${CONDA_OUTER_BASE}"/{apps,modules,scripts}

rsync --archive --verbose --partial --progress --one-file-system --hard-links --acls -- "${CONDA_OUTER_BASE}"/{apps,modules,scripts} "${CONDA_BASE}"

mkdir -p "${ADMIN_DIR}"

pushd "${CONDA_OUTER_BASE}"
tar -cf "${ADMIN_DIR}"/conda_base.tar {apps,modules,scripts}
popd
