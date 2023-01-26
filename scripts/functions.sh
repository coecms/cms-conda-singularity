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
            chmod g+s "${arg}"
            setfacl -R -m g:"${APPS_OWNERS_GROUP}":rwX,d:g:"${APPS_OWNERS_GROUP}":rwX "${arg}"
        elif [[ -f "${arg}" ]]; then
            ### reset any existing acls
            setfacl -b "${arg}"
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

function set_admin_perms() {

    for arg in "$@"; do
        if [[ -d "${arg}" ]]; then
            chgrp -R "${APPS_USERS_GROUP}" "${arg}"
            chmod -R g=u,o= "${arg}"
            chmod g+s "${arg}"
            setfacl -R -m g:"${APPS_USERS_GROUP}":---,g:"${APPS_OWNERS_GROUP}":rwX,d:g:"${APPS_USERS_GROUP}":---,d:g:"${APPS_OWNERS_GROUP}":rwX "${arg}"
        elif [[ -f "${arg}" ]]; then
            ### reset any existing acls
            setfacl -b "${arg}"
            chgrp "${APPS_USERS_GROUP}" "${arg}"
            chmod g=u,o= "${arg}"
            if [[ -x "${arg}" ]]; then
                setfacl -m g:"${APPS_USERS_GROUP}":---,g:"${APPS_OWNERS_GROUP}":rwX "${arg}"
            else
                setfacl -m g:"${APPS_USERS_GROUP}":---,g:"${APPS_OWNERS_GROUP}":rw "${arg}"
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
    module_name="${5}"

    cat<<EOF > "${module_path}"/"${module_name}"/.modulerc
#%Module1.0

module-version ${module_name}/${stable} analysis ${env_name} default
module-version ${module_name}/${unstable} ${env_name}-unstable

module-version ${module_name}/analysis27-18.10 analysis27
EOF

    set_apps_perms "${module_path}/${module_name}/.modulerc"

}

function symlink_atomic_update() {
    link_name="${1}"
    link_target="${2}"

    tmp_link_name=$( mktemp -u -p ${link_name%/*} .tmp.XXXXXXXX )

    ln -s "${link_target}" "${tmp_link_name}"
    mv -T "${tmp_link_name}" "${link_name}"

    set_apps_perms "${link_name}"
}

function copy_and_replace() {
    ### Copies the file in $1 to the location in $2 and replaces any occurence
    ### of __${3}__, __${4}__... with the contents of those environment variables
    in="${1}"
    out="${2}"
    shift 2
    sedstr=''
    for arg in "$@"; do
        sedstr="${sedstr}s:__${arg}__:${!arg}:g;"
    done
    
    if [[ "${sedstr}" ]]; then
        sed "${sedstr}" < "${in}" > "${out}"
    else
        cp "${in}" "${out}"
    fi

}