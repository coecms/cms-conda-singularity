#!/usr/bin/env bash
script=$( realpath -s "${0}" )
overrides_bin=$( dirname "${script}" )
source "${overrides_bin}"/functions.sh

exec $( findreal ssh ) "$@"