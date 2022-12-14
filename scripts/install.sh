#!/usr/bin/env bash

### Run me inside a singularity container launched with the following command:
###
### mkdir -p $PBS_JOBFS/overlay
### /opt/singularity/bin/singularity -s exec --bind /etc,/half-root,/local,/ram,/run,/system,/usr,/var/lib/sss,/var/run/munge,/var/lib/rpm,$PBS_JOBFS/overlay:/g /g/data/v45/dr4292/singularity/test.sif initialise.sh
### The important part is the $PBS_JOBFS:/g mount - we need an empty /g/data for this

export CONDA_BASE=/g/data/v45/dr4292/conda_concept
export FULLENV=analysis3-22.12
declare -a rpms_to_remove=( "openssh-clients" "openssh-server" "openssh" )
declare -a replace_from_apps=( "openmpi/4.1.4" )

export OWD="${OWD:-/home/563/dr4292/cms-conda-singularity/scripts}"
export CONDA_INSTALLATION_PATH=${CONDA_INSTALLATION_PATH:-${CONDA_BASE}/apps/miniconda3}
export ENV_INSTALLATION_PATH="${PBS_JOBFS}"/squashfs-root/opt/conda/"${FULLENV}"
export MAMBA="${CONDA_INSTALLATION_PATH}"/condabin/mamba

mkdir -p "${ENV_INSTALLATION_PATH}"
mkdir -p "${CONDA_INSTALLATION_PATH%/*}"

pushd "${CONDA_BASE}"

tar -cf "${OWD}"/conda_base.tar
ln -s "${ENV_INSTALLATION_PATH}" apps/miniconda3/envs/

popd

source "${CONDA_INSTALLATION_PATH}"/etc/profile.d/conda.sh
### Create the environment
${MAMBA} env create -p "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}" -f environment.yml

### Create symlink tree
mkdir -p "${CONDA_BASE}"/scripts/"${FULLENV}".d/{bin,overrides}
cp "${CONDA_BASE}"/scripts/{launcher.sh,launcher_conf.sh} "${CONDA_BASE}"/scripts/"${FULLENV}".d/bin
pushd "${CONDA_BASE}"/scripts/"${FULLENV}".d/bin
for i in $( ls "${ENV_INSTALLATION_PATH}"/bin ); do
    ln -s launcher.sh $i
done
popd

pushd "${CONDA_BASE}"/scripts/"${FULLENV}".d/overrides
for i in ../../overrides/*; do
    ln -s ${i}
done
popd

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

set +u
conda activate "${CONDA_INSTALLATION_PATH}/envs/${FULLENV}"
set -u

py.test -s
# Refresh jupyter plugins
jupyter lab build