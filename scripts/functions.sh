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
