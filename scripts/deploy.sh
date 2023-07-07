#!/usr/bin/env bash
set -eu

[[ "${SCRIPT_DIR}" ]] && cd "${SCRIPT_DIR}"

export CONDA_TEMP_PATH=$( mktemp -d -p "${BUILD_STAGE_DIR}" )
trap 'rm -rf "${CONDA_TEMP_PATH}"' EXIT

source install_config.sh
source functions.sh

export CONDA_INSTALLATION_PATH=${CONDA_INSTALLATION_PATH:-${CONDA_BASE}/./${APPS_SUBDIR}/${CONDA_INSTALL_BASENAME}}

### Do not package conda_base.tar or the updated env if there was no change
if diff -q "${BUILD_STAGE_DIR}"/deployed.yml "${BUILD_STAGE_DIR}"/deployed.old.yml; then
    echo "No changes detected in the environment, not deploying"
    rm -f "${BUILD_STAGE_DIR}"/deployed.yml "${BUILD_STAGE_DIR}"/deployed.old.yml
    exit
fi

mkdir -p "${CONDA_TEMP_PATH}"
pushd "${CONDA_TEMP_PATH}"
### WARNING: Non-standard tar extension: --acls
tar --acls -xf "${BUILD_STAGE_DIR}"/conda_base.tar
popd

### rsync --archive attempts to set permissions on 
### "${CONDA_BASE}" itself, which results in errors.
set +e
echo "Sync across any changes in the base conda environment"
rsync --archive --verbose --partial --progress --one-file-system --itemize-changes --hard-links --acls --relative -- "${CONDA_TEMP_PATH}"/./"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}" "${CONDA_TEMP_PATH}"/./"${MODULE_SUBDIR}" "${CONDA_TEMP_PATH}"/./"${SCRIPT_SUBDIR}" "${CONDA_BASE}"

echo "Make sure anything deleted from the base conda environment is also deleted in the prod copy"
rsync --archive --verbose --partial --progress --one-file-system --itemize-changes --hard-links --acls --relative --delete --exclude=*.sqsh -- "${CONDA_TEMP_PATH}"/./"${APPS_SUBDIR}"/"${CONDA_INSTALL_BASENAME}" "${CONDA_BASE}"

echo "Make sure anything deleted from the scripts directory is also deleted from the prod copy"
rsync --archive --verbose --partial --progress --one-file-system --itemize-changes --hard-links --acls --relative --delete -- "${CONDA_TEMP_PATH}"/./"${SCRIPT_SUBDIR}" "${CONDA_BASE}"
set -e

[[ -e "${CONDA_INSTALLATION_PATH}"/envs/"${FULLENV}".sqsh ]] && cp "${CONDA_INSTALLATION_PATH}"/envs/"${FULLENV}".sqsh "${ADMIN_DIR}"/"${FULLENV}".sqsh.bak
mv "${BUILD_STAGE_DIR}"/"${FULLENV}".sqsh.tmp "${CONDA_INSTALLATION_PATH}"/envs/"${FULLENV}".sqsh

### Update stable/unstable if necessary
CURRENT_STABLE=$( get_aliased_module "${MODULE_NAME}"/access-med "${CONDA_MODULE_PATH}" )
NEXT_STABLE="${ENVIRONMENT}-${STABLE_VERSION}"
CURRENT_UNSTABLE=$( get_aliased_module "${MODULE_NAME}"/access-med-unstable "${CONDA_MODULE_PATH}" )
NEXT_UNSTABLE="${ENVIRONMENT}-${UNSTABLE_VERSION}"

if ! [[ "${CURRENT_STABLE}" == "${MODULE_NAME}/${NEXT_STABLE}" ]]; then
    echo "Updating stable environment to ${NEXT_STABLE}"
    write_modulerc "${NEXT_STABLE}" "${NEXT_UNSTABLE}" "${ENVIRONMENT}" "${CONDA_MODULE_PATH}" "${MODULE_NAME}"
    symlink_atomic_update "${CONDA_INSTALLATION_PATH}"/envs/"${ENVIRONMENT}" "${NEXT_STABLE}"
    symlink_atomic_update "${CONDA_SCRIPT_PATH}"/"${ENVIRONMENT}".d "${NEXT_STABLE}".d
fi
if ! [[ "${CURRENT_UNSTABLE}" == "${MODULE_NAME}/${NEXT_UNSTABLE}" ]]; then
    echo "Updating unstable environment to ${NEXT_UNSTABLE}"
    write_modulerc "${NEXT_STABLE}" "${NEXT_UNSTABLE}" "${ENVIRONMENT}" "${CONDA_MODULE_PATH}" "${MODULE_NAME}"
    symlink_atomic_update "${CONDA_INSTALLATION_PATH}"/envs/"${ENVIRONMENT}"-unstable "${NEXT_UNSTABLE}"
    symlink_atomic_update "${CONDA_SCRIPT_PATH}"/"${ENVIRONMENT}"-unstable.d "${NEXT_UNSTABLE}".d
fi

### Overwrite existing conda_base tarball
mv "${BUILD_STAGE_DIR}"/conda_base.tar "${ADMIN_DIR}"
### Remove staging artefacts
rm -f "${BUILD_STAGE_DIR}"/deployed.yml "${BUILD_STAGE_DIR}"/deployed.old.yml "${BUILD_STAGE_DIR}"/"${FULLENV}".sqsh.tmp