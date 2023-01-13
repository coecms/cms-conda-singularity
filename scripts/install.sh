#!/usr/bin/env bash

[[ "${SCRIPT_DIR}" ]] && cd "${SCRIPT_DIR}"

source install_config.sh
source functions.sh

### Derived temp file locations
export OVERLAY_BASE="${CONDA_TEMP_PATH}"/overlay
export CONDA_OUTER_BASE="${OVERLAY_BASE}"/"${CONDA_BASE#/*/}"
export ENV_INSTALLATION_PATH="${CONDA_TEMP_PATH}"/squashfs-root/opt/conda/"${FULLENV}"

### Derived installation paths
export CONDA_INSTALLATION_PATH=${CONDA_INSTALLATION_PATH:-${CONDA_BASE}/./${APPS_SUBDIR}/${CONDA_INSTALL_BASENAME}}
export MAMBA="${CONDA_INSTALLATION_PATH}"/condabin/mamba

if [[ ! -d "${CONDA_INSTALLATION_PATH}" ]]; then
    echo "Base installation not present - initialising"
    ./initialise.sh
fi

function inner() {

    source "${CONDA_INSTALLATION_PATH}"/etc/profile.d/conda.sh
    ### Create the environment
    if [[ "${1}" == "--install" ]]; then
        ${MAMBA} env create -p "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}" -f environment.yml
        if [[ $? -ne 0 ]]; then
            echo "Error installing new environment"
            exit 1
        fi
    elif [[ "${1}" == "--update" ]]; then
        cat "${CONDA_INSTALLATION_PATH}"/envs/${FULLENV}/conda-meta/history >> "${CONDA_INSTALLATION_PATH}"/envs/${FULLENV}/conda-meta/history.log
        echo > "${CONDA_INSTALLATION_PATH}"/envs/${FULLENV}/conda-meta/history
        conda env export -p "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}" > deployed.old.yml
        ${MAMBA} env update -p "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}" -f environment.yml
        if [[ $? -ne 0 ]]; then
            echo "Error updating new environment"
            exit 1
        fi

        ### Destroy the existing symlink tree
        rm -rf "${CONDA_SCRIPT_PATH}"/"${FULLENV}".d/{bin,overrides}
    fi
    
    conda env export -p "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}" > deployed.yml

    if [[ "${1}" == "--update" ]] && diff -q deployed.yml deployed.old.yml; then
        echo "No changes detected in the environment, discarding update"
        exit 0
    fi

    pushd "${ENV_INSTALLATION_PATH}"
    ### Get rid of stuff from packages we don't want
    for dir in bin lib etc libexec include; do 
        pushd $dir
        for i in $( rpm -qli "${rpms_to_remove[@]}" ); do 
            fn=$( basename $i )
            [[ -f $fn ]] && rm $fn
            [[ -d $fn ]] && rm -rf $fn
        done
        popd
    done

    ### Replace things from apps
    for pkg in "${replace_from_apps[@]}"; do
        for dir in bin etc lib include; do 
            pushd $dir 
            for i in $( find /apps/$pkg/$dir -maxdepth 1 -type f ); do 
                fn=$( basename $i ) 
                [[ -e $fn ]] && rm $fn && ln -s $i
            done
            popd
        done
    done
    popd

    ### Create symlink tree
    mkdir -p "${CONDA_SCRIPT_PATH}"/"${FULLENV}".d/{bin,overrides}
    cp "${CONDA_SCRIPT_PATH}"/{launcher.sh,launcher_conf.sh} "${CONDA_SCRIPT_PATH}"/"${FULLENV}".d/bin
    pushd "${CONDA_SCRIPT_PATH}"/"${FULLENV}".d/bin
    for i in $( ls "${ENV_INSTALLATION_PATH}"/bin ); do
        ln -s launcher.sh $i
    done

    ### Add in the outside commands
    for i in "${outside_commands_to_include[@]}"; do
        ln -s launcher.sh $i
    done
    popd

    ### Add in the override and config scripts
    pushd "${CONDA_SCRIPT_PATH}"/"${FULLENV}".d/overrides
    for i in ../../overrides/*; do
        ln -s ${i}
    done
    popd

    set +u
    conda activate "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}"
    set -u

    jupyter lab build

    conda clean -a -f -y

    ### For reasons I can't figure out, py.test hangs on exit due to not being able to
    ### clean up one of its threads when run in singularity. To get around this, background
    ### py.test and read its status from an output file, rather than using the exit status
    rm -f "${TEST_OUT_FILE}"
    py.test -s --junitxml "${TEST_OUT_FILE}" &
    test_pid=$!

    while ! [[ -e "${TEST_OUT_FILE}" ]]; do sleep 5; done

    [[ -e /proc/"${test_pid}" ]] && kill -15 "${test_pid}"
    wait

}

if [[ "${1}" == '--inner' ]]; then
    inner "${2}"
    exit 0
fi

mkdir -p "${CONDA_OUTER_BASE}"
echo "Copying base conda installation to ${CONDA_TEMP_PATH}"
rsync --recursive --links --perms --times --specials --partial --one-file-system --hard-links --acls --relative --exclude=*.sqsh -- "${CONDA_INSTALLATION_PATH}" "${CONDA_SCRIPT_PATH}" "${CONDA_MODULE_PATH}" "${CONDA_OUTER_BASE}"/
echo "Done"

if [[ -e  "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}.sqsh" ]]; then
    pushd "${CONDA_TEMP_PATH}"
    unsquashfs -processors 1 "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}.sqsh"
    popd
    rm "${CONDA_OUTER_BASE}"/"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}"/envs/"${FULLENV}"
    export DO_UPDATE="--update"
else
    mkdir -p "${ENV_INSTALLATION_PATH}"
    export DO_UPDATE="--install"
fi

ln -sf "${ENV_INSTALLATION_PATH}" "${CONDA_OUTER_BASE}"/"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}"/envs/

/opt/singularity/bin/singularity -s exec --bind /etc,/half-root,/local,/ram,/run,/system,/usr,/var/lib/sss,/var/run/munge,/var/lib/rpm,"${OVERLAY_BASE}":/g "${CONTAINER_PATH}" $( realpath $0 ) --inner "${DO_UPDATE}"
if [[ $? -ne 0 ]]; then
    exit 1
fi

### See if the container has been updated
read newhash fn < <( md5sum "${CONTAINER_PATH}" )
read oldhash fn < <( md5sum "${CONDA_OUTER_BASE}"/"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}"/etc/"${CONTAINER_PATH##*/}" )
if [[ "${oldhash}" != "${newhash}" ]]; then
    echo "Container update detected. Copying in new container"
    cp "${CONTAINER_PATH}" "${CONDA_OUTER_BASE}"/"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}"/etc/"${CONTAINER_PATH##*/}"
fi

### Do not package conda_base.tar or the updated env if there was no change
if [[ "${DO_UPDATE}" == "--update" ]] && diff -q deployed.yml deployed.old.yml; then
    exit
fi

read errors failures < <( python3 -c 'import xml.etree.ElementTree as ET; import sys; t=ET.parse(sys.argv[1]); print(t.getroot().getchildren()[0].get("errors") + " " + t.getroot().getchildren()[0].get("failures"))' "${TEST_OUT_FILE}" )

if [[ "${errors}" -gt 0 ]] || [[ "${failures}" -gt 0 ]]; then
    echo "TESTS FAILED - discarding update"
    exit
fi


if [[ "${DO_UPDATE}" == "--install" ]]; then
    ln -s .common_v3 "${CONDA_OUTER_BASE}"/"${MODULE_SUBDIR}"/conda/"${FULLENV}"
fi

pushd "${CONDA_TEMP_PATH}"
### Set permissions
### Don't need to think too hard, squashfs are read-only
chgrp -R "${APPS_USERS_GROUP}" squashfs-root

mksquashfs squashfs-root "${FULLENV}".sqsh -b 1M -no-recovery -noI -noD -noF -noX -processors 8 2>/dev/null
### Stage this file and rename when we're ready
cp "${FULLENV}".sqsh "${ADMIN_DIR}"/"${FULLENV}".sqsh.tmp
popd

rm "${CONDA_OUTER_BASE}"/"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}"/envs/"${FULLENV}"
ln -s /opt/conda/"${FULLENV}" "${CONDA_OUTER_BASE}"/"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}"/envs/

### Set permissions on base environment
set_apps_perms "${CONDA_OUTER_BASE}"/"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}" "${CONDA_OUTER_BASE}"/"${MODULE_SUBDIR}" "${CONDA_OUTER_BASE}"/"${SCRIPT_SUBDIR}"

echo "Sync across any changes in the base conda environment"
rsync --archive --verbose --partial --progress --one-file-system --itemize-changes --hard-links --acls --relative -- "${CONDA_OUTER_BASE}"/./"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}" "${CONDA_OUTER_BASE}"/./"${MODULE_SUBDIR}" "${CONDA_OUTER_BASE}"/./"${SCRIPT_SUBDIR}" "${CONDA_BASE}"

echo "Make sure anything deleted from the base conda environment is also deleted in the prod copy"
rsync --archive --verbose --partial --progress --one-file-system --itemize-changes --hard-links --acls --relative --delete --exclude=*.sqsh -- "${CONDA_OUTER_BASE}"/./"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}" "${CONDA_BASE}"

echo "Make sure anything deleted from the scripts directory is also deleted from the prod copy"
rsync --archive --verbose --partial --progress --one-file-system --itemize-changes --hard-links --acls --relative --delete -- "${CONDA_OUTER_BASE}"/./"${SCRIPT_SUBDIR}" "${CONDA_BASE}"

[[ "${DO_UPDATE}" == "--update" ]] && cp "${CONDA_INSTALLATION_PATH}"/envs/"${FULLENV}".sqsh "${ADMIN_DIR}"/"${FULLENV}".sqsh.bak
set_apps_perms "${ADMIN_DIR}"/"${FULLENV}".sqsh.tmp
mv "${ADMIN_DIR}"/"${FULLENV}".sqsh.tmp "${CONDA_INSTALLATION_PATH}"/envs/"${FULLENV}".sqsh

### Update stable/unstable if necessary
CURRENT_STABLE=$( get_aliased_module conda/analysis "${CONDA_MODULE_PATH}" )
NEXT_STABLE="${ENVIRONMENT}-${STABLE_VERSION}"
CURRENT_UNSTABLE=$( get_aliased_module conda/analysis3-unstable "${CONDA_MODULE_PATH}" )
NEXT_UNSTABLE="${ENVIRONMENT}-${UNSTABLE_VERSION}"

if ! [[ "${CURRENT_STABLE}" == "conda/${NEXT_STABLE}" ]]; then
    echo "Updating stable environment to ${NEXT_STABLE}"
    write_modulerc "${NEXT_STABLE}" "${NEXT_UNSTABLE}" "${ENVIRONMENT}" "${CONDA_MODULE_PATH}" 
    symlink_atomic_update "${CONDA_INSTALLATION_PATH}"/envs/"${ENVIRONMENT}" "${NEXT_STABLE}"
    symlink_atomic_update "${CONDA_SCRIPT_PATH}"/"${ENVIRONMENT}".d "${NEXT_STABLE}".d
fi
if ! [[ "${CURRENT_UNSTABLE}" == "conda/${NEXT_UNSTABLE}" ]]; then
    echo "Updating unstable environment to ${NEXT_UNSTABLE}"
    write_modulerc "${NEXT_STABLE}" "${NEXT_UNSTABLE}" "${ENVIRONMENT}" "${CONDA_MODULE_PATH}" 
    symlink_atomic_update "${CONDA_INSTALLATION_PATH}"/envs/"${ENVIRONMENT}"-unstable "${NEXT_UNSTABLE}"
    symlink_atomic_update "${CONDA_SCRIPT_PATH}"/"${ENVIRONMENT}"-unstable.d "${NEXT_UNSTABLE}".d
fi


### Archive base env
pushd "${CONDA_OUTER_BASE}"
tar -cf "${ADMIN_DIR}"/conda_base.tar "${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}" "${MODULE_SUBDIR}" "${SCRIPT_SUBDIR}"
popd
