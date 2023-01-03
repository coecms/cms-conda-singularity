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
export VERSION_TO_MODIFY=22.10
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