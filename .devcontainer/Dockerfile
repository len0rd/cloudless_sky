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

#############################
FROM base AS cmake_downloader
#############################

# Set the cmake version to use
# Possible options are listed here: https://github.com/Kitware/CMake/tags
ARG CMAKE_VERSION=3.26.4
RUN mkdir -p /opt/cmake \
    && wget ${WGET_ARGS} "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh" \
        -O /cmake.sh \
    && sh /cmake.sh --skip-license --prefix=/opt/cmake \
    && rm /cmake.sh

################
FROM base AS dev
################

# love and opengl
RUN add-apt-repository -y ppa:bartbes/love-stable \
    && apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -yq \
        love \
        mesa-utils \
        libluajit-5.1-dev \
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

COPY --from=cmake_downloader /opt/cmake /opt/cmake
ENV PATH=$PATH:/opt/cmake/bin

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
