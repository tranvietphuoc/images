#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e

wrapper=""
if [[ "${RESTARTABLE}" == "yes" ]]; then
    wrapper="run-one-constantly"
fi

if [[ -n "${JUPYTERHUB_API_TOKEN}" ]]; then
    exec /usr/local/bin/singleuser.sh "$@"
elif [[ -n "${JUPYTER_ENABLE_LAB}" ]]; then
    # JupyterLab is now the default in modern stacks, but we keep the check
    . /usr/local/bin/start.sh ${wrapper} jupyter lab "$@"
else
    # Launch JupyterLab by default as Notebook 7 is built on Lab components
    . /usr/local/bin/start.sh ${wrapper} jupyter lab "$@"
fi
