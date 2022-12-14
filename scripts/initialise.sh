#!/usr/bin/env bash

### Run me inside a singularity container launched with the following command:
###
### mkdir ${PBS_JOBFS}/overlay
### /opt/singularity/bin/singularity -s exec --bind /etc,/haoot,/local,/ram,/run,/system,/usr,/var/lib/sss,/var/run/munge,$PBS_JOBFS/overlay:/g /g/data/v45/dr4292/singularity/test.sif initialise.sh
### The important part is the $PBS_JOBFS/overlay:/g mount - we need an empty /g/data for this

export OWD=${PWD}
export CONDA_BASE=/g/data/v45/dr4292/conda_concept

export CONDA_INSTALLATION_PATH=${CONDA_INSTALLATION_PATH:-$CONDA_BASE/apps/miniconda3}
mkdir -p "${CONDA_INSTALLATION_PATH%/*}"
### Placeholder for script that will initialise the base conda environment from scratch
wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.12.0-Linux-x86_64.sh
bash Miniconda3-py39_4.12.0-Linux-x86_64.sh -b -p "${CONDA_INSTALLATION_PATH}"

. "${CONDA_INSTALLATION_PATH}"/etc/profile.d/conda.sh
conda install mamba -y

export CONDA_SCRIPT_PATH="${CONDA_BASE}"/scripts
export CONDA_MODULE_PATH="${CONDA_BASE}"/modules

mkdir -p "${CONDA_SCRIPT_PATH}"/overrides
cp "${OWD}"/launcher{,_conf}.sh "${CONDA_SCRIPT_PATH}"
cp "${OWD}"/overrides/* "${CONDA_SCRIPT_PATH}"/overrides

mkdir -p "${CONDA_MODULE_PATH}"/conda
cp "${OWD}"/condaenv.sh "${CONDA_MODULE_PATH}"/conda
cp "${OWD}"/../modules/common_v3 "${CONDA_MODULE_PATH}"/conda/.common_v3

conda clean -a -f -y

pushd "${CONDA_BASE}"
tar -cf "${OWD}"/conda_base.tar apps modules scripts
popd

### Then untar into the real ${CONDA_INSTALLATION_PATH}