# For VSCode Devcontainer and CI
#########################
FROM ubuntu:24.04 AS base
#########################


# core dependencies
RUN apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -yq --no-install-recommends \
        wget \
        tar \
        xz-utils \
        ca-certificates \
        # default gcc is used for linux build
        gcc \
        build-essential \
        # for add-apt-repository
        software-properties-common \
    && rm -rf /var/lib/apt/list \
    # ensure certs are up to date
    && update-ca-certificates

# love and opengl
RUN add-apt-repository -y ppa:bartbes/love-stable \
    && apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -yq \
        love \
        mesa-utils \
        # lua package manager
        luarocks \
    && rm -rf /var/lib/apt/list

# build tools
COPY python-requirements.txt reqs.txt
RUN apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -yq --no-install-recommends \
        python3 \
        python3-pip \
        python-is-python3 \
        # needed by appimagetool
        file \
        # tab-completion of things while in a shell
        bash-completion \
    && pip install --break-system-packages -r reqs.txt \
    && rm ./reqs.txt \
    && rm -rf /var/lib/apt/list

# dev tools
RUN apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -yq --no-install-recommends \
        git \
        ssh \
    && rm -rf /var/lib/apt/list

ENV USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# create non-root user to use
# the 24.04 container already has a user @ 1000:1000 named 'ubuntu'. Rename it
RUN userdel -r ubuntu \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -d /home/${USERNAME} -s /bin/bash ${USERNAME}

USER $USERNAME
WORKDIR /home/$USERNAME
