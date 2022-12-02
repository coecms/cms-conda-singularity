#!/bin/bash
# Prints the environment variables set by 'conda activate $1', for processing by the modules
export PATH=/usr/bin:/bin
source "${1}"/etc/profile.d/conda.sh
conda activate "${2}"
/bin/env
alias