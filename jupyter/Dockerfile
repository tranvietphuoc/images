# Ubuntu 24.04 (noble)
# Copyright (c) Jupyter Development Team.
# Modified by Antigravity for User

# syntax=docker/dockerfile:1

# =============================================================================
# Stage 1: Conda Builder
# =============================================================================
FROM debian:bookworm-slim AS conda-builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    bash \
    ca-certificates \
    binutils \
    && rm -rf /var/lib/apt/lists/*

ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:$PATH
ARG PYTHON_VERSION=3.14
ARG NB_GID=100
ENV NB_GID=${NB_GID}


WORKDIR /tmp
RUN set -x && \
    miniforge_arch=$(uname -m) && \
    miniforge_installer="Miniforge3-Linux-${miniforge_arch}.sh" && \
    wget --quiet "https://github.com/conda-forge/miniforge/releases/latest/download/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    # Install Python 3.14
    if [[ "${PYTHON_VERSION}" != "default" ]]; then mamba install --quiet --yes python="${PYTHON_VERSION}"; fi && \
    # Install Stack
    mamba install --quiet --yes \
    'notebook' \
    'jupyterhub' \
    'jupyterlab' \
    'altair' \
    'beautifulsoup4' \
    'plotly' \
    'bottleneck' \
    'cloudpickle' \
    'conda-forge::blas=*=openblas' \
    'cython' \
    'h5py' \
    'ipympl'\
    'ipywidgets' \
    'matplotlib-base' \
    'numba' \
    'numexpr' \
    'pandas' \
    'numpy' \
    'patsy' \
    'protobuf' \
    'pytables' \
    'scikit-image' \
    'scikit-learn' \
    'scipy' \
    'seaborn' \
    'sqlalchemy' \
    'psycopg2-binary' \
    'statsmodels' \
    'sympy' \
    'openpyxl'\
    'black' \
    'ruff' \
    && \
    pip install "mistune<2" nb2xls jupyterlab-git opencv-python-headless && \
    # Cleanup aggressive
    jupyter lab clean -y && \
    npm cache clean --force || true && \
    mamba clean --all -f -y && \
    find ${CONDA_DIR} -follow -type f -name '*.js.map' -delete && \
    # Aggressive Cleanup
    find ${CONDA_DIR} -name '*.a' -delete && \
    find ${CONDA_DIR} -name '__pycache__' -type d -exec rm -rf '{}' + && \
    # Deep Clean: Remove tests
    find ${CONDA_DIR} -name 'tests' -type d -exec rm -rf '{}' + && \
    find ${CONDA_DIR} -name 'test' -type d -exec rm -rf '{}' + && \
    # Remove documentation and tests
    rm -rf ${CONDA_DIR}/share/doc \
           ${CONDA_DIR}/share/man \
           ${CONDA_DIR}/share/info

COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions && \
    /usr/local/bin/fix-permissions "${CONDA_DIR}"

# =============================================================================
# Stage 2: Rust Builder
# =============================================================================
FROM debian:bookworm-slim AS rust-builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    cmake \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV RUSTUP_HOME=/opt/rust
ENV CARGO_HOME=/opt/cargo
ENV PATH=${CARGO_HOME}/bin:$PATH
ARG NB_GID=100
ENV NB_GID=${NB_GID}

RUN set -eux; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path; \
    chmod -R a+w ${RUSTUP_HOME} ${CARGO_HOME}; \
    cargo install evcxr_jupyter; \
    # Cleanup registry to save space
    rm -rf "${CARGO_HOME}/registry" "${CARGO_HOME}/git"

COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions && \
    /usr/local/bin/fix-permissions "${RUSTUP_HOME}" "${CARGO_HOME}"

# =============================================================================
# Stage 3: Final Image
# =============================================================================
FROM debian:bookworm-slim

LABEL maintainer="phuoctv"
# ARGs must be defined again in the final stage
ARG NB_USER="phuoc"
ARG NB_UID="1000"
ARG NB_GID="100"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Install runtime dependencies (minimal)
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    tini \
    wget \
    curl \
    git \
    ca-certificates \
    sudo \
    locales \
    locales \
    # Rust runtime deps (evcxr compiles on the fly)
    gcc \
    libc6-dev \
    && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Create User first to ensure UIDs are consistent for COPY
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    # Remove default ubuntu user if it exists to free up UID 1000
    if getent passwd 1000; then userdel -f $(getent passwd 1000 | cut -d: -f1); fi && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    chmod g+w /etc/passwd

# Setup Environment
ENV CONDA_DIR=/opt/conda \
    RUSTUP_HOME=/opt/rust \
    CARGO_HOME=/opt/cargo \
    SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ENV PATH="${CONDA_DIR}/bin:${CARGO_HOME}/bin:${PATH}" \
    HOME="/home/${NB_USER}"

# Copy Conda env with ownership (Avoids duplicating layer with chown -R)
COPY --chown=${NB_UID}:${NB_GID} --from=conda-builder ${CONDA_DIR} ${CONDA_DIR}

# Copy Rust toolchain and Kernel with ownership
COPY --chown=${NB_UID}:${NB_GID} --from=rust-builder ${RUSTUP_HOME} ${RUSTUP_HOME}
COPY --chown=${NB_UID}:${NB_GID} --from=rust-builder ${CARGO_HOME} ${CARGO_HOME}

# Copy scripts
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Final Permissions fix (only for Home, avoiding massive recursive chowns on correct dirs)
RUN fix-permissions "${HOME}"

# Shell config
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
    echo 'eval "$(command conda shell.bash hook 2> /dev/null)"' >> /etc/skel/.bashrc

# Copy helper scripts
COPY --chmod=755 start.sh notebook.sh singleuser.sh run-one-constantly /usr/local/bin/
COPY jupyter_config.py /etc/jupyter/jupyter_server_config.py
RUN fix-permissions /etc/jupyter/

# Pre-compile matplotlib font cache and final permissions
USER ${NB_UID}
ARG PYTHON_VERSION=3.14

RUN mkdir "/home/${NB_USER}/work" && \
    fix-permissions "/home/${NB_USER}" && \
    # Install Evcxr Kernel (needs to be run where jupyter is available)
    evcxr_jupyter --install && \
    MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    # Final cleanup of runtime generated caches
    find "/home/${NB_USER}" -name '__pycache__' -type d -exec rm -rf '{}' + && \
    fix-permissions "/home/${NB_USER}"

WORKDIR "${HOME}"
EXPOSE 8888
ENTRYPOINT ["tini", "-g", "--"]
CMD ["notebook.sh"]
