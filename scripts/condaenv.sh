#!/bin/bash
# Prints the environment variables set by 'conda activate $1', for processing by the modules
export PATH=/usr/bin:/bin
eval "$( "${1}"/bin/micromamba shell hook -s bash )"
micromamba activate "${2}"
/bin/env
alias