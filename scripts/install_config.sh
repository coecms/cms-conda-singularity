### Settings to control installation path e.g. for test installs
export CONDA_BASE="${CONDA_BASE:-/g/data/hh5/admin/conda_concept}"
export ADMIN_DIR="${ADMIN_DIR:-${CONDA_BASE}/admin}"
export CONDA_TEMP_PATH="${PBS_JOBFS:-${CONDA_TEMP_PATH}}"
export SCRIPT_DIR="${SCRIPT_DIR:-$PWD}"

### Derived locations
export CONDA_SCRIPT_PATH="${CONDA_BASE}"/scripts
export CONDA_MODULE_PATH="${CONDA_BASE}"/modules

### Groups
export APPS_USERS_GROUP=hh5
export APPS_OWNERS_GROUP=hh5_w

### Version settings
export ENVIRONMENT=analysis3
export VERSION_TO_MODIFY=22.07
export STABLE_VERSION=22.07
export UNSTABLE_VERSION=22.10
export FULLENV="${ENVIRONMENT}-${VERSION_TO_MODIFY}"

### Other settings
export TEST_OUT_FILE=test_results.xml
export PYTHONNOUSERSITE=true
export CONTAINER_PATH=$( realpath "${SCRIPT_DIR}"/../container/test.sif )

declare -a rpms_to_remove=( "openssh-clients" "openssh-server" "openssh" )
declare -a replace_from_apps=( "openmpi/4.1.4" )
declare -a outside_commands_to_include=( "pbs_tmrsh" "ssh" )

### Useful functions
function get_aliased_module () {
    alias_name="${1}"
    module_path="${2}"
    while read al arrow mod; do 
        if [[ "${al}" == "${alias_name}" ]]; then
            echo "${mod}"
            return
        fi
    done < <( MODULEPATH="${module_path}" module aliases 2>&1 )
    echo ""
    return
}

function set_apps_perms() {

    for arg in "$@"; do
        if [[ -d "${arg}" ]]; then
            chgrp -R "${APPS_USERS_GROUP}" "${arg}"
            chmod -R g=u-w,o= "${arg}"
            setfacl -R -m g:"${APPS_OWNERS_GROUP}":rwX,d:g:"${APPS_OWNERS_GROUP}":rwX "${arg}"
        elif [[ -f "${arg}" ]]; then
            chgrp "${APPS_USERS_GROUP}" "${arg}"
            chmod g=u-w,o= "${arg}"
            if [[ -x "${arg}" ]]; then
                setfacl -m g:"${APPS_OWNERS_GROUP}":rwX "${arg}"
            else
                setfacl -m g:"${APPS_OWNERS_GROUP}":rw "${arg}"
            fi
        elif [[ -h "${arg}" ]]; then
            chgrp -h "${APPS_USERS_GROUP}" "${arg}"
        fi
    done
}

function write_modulerc() {
    stable="${1}"
    unstable="${2}"
    env_name="${3}"
    module_path="${4}"

    cat<<EOF > "${module_path}/conda/.modulerc"
#%Module1.0

module-version conda/${stable} analysis ${env_name} default
module-version conda/${unstable} ${env_name}-unstable

module-version conda/analysis27-18.10 analysis27
EOF

    set_apps_perms "${module_path}/conda/.modulerc"

}

function symlink_atomic_update() {
    link_name="${1}"
    link_target="${2}"

    tmp_link_name=$( mktemp -u -p ${link_name%/*} .tmp.XXXXXXXX )

    ln -s "${link_target}" "${tmp_link_name}"
    mv -T "${tmp_link_name}" "${link_name}"

    set_apps_perms "${link_name}"
}
