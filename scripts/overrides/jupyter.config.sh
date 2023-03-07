for i in "${CONDA_BASE_ENV_PATH}"/envs/*.sqsh; do
    [[ :"${CONTAINER_OVERLAY_PATH}": =~ :"${i}": ]] || CONTAINER_OVERLAY_PATH="${CONTAINER_OVERLAY_PATH}":"${i}"
done
### Strip leading and/or trailing colons
CONTAINER_OVERLAY_PATH="${CONTAINER_OVERLAY_PATH#:}"
export CONTAINER_OVERLAY_PATH="${CONTAINER_OVERLAY_PATH%:}"