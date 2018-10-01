#!/usr/bin/env bash

# Presence of this file indicates whether this is a personal system
BOOTSTRAP_PERSONAL="${HOME}/.bootstrap_personal"

export STARTUP_DIR="${HOME}/.startup"
STARTUP_BACKUP_DIR="${HOME}/.startup_backup"

function link_startup_file() {

    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    startup_backup_dir="${STARTUP_BACKUP_DIR}/${backup_timestamp}"
    mkdir -p ${startup_backup_dir}

    source_file_name=$1
    if [ "$2" == "" ]; then
        full_source_file_name="${STARTUP_DIR}/dotfiles/${source_file_name}"
    else
        # Presence of source_prefix is also a marker for a personal system.
        # So link from reference copy
        source_prefix=$2
        # Don't link bash_local to reference. Leave it local
        if [ "$source_file_name" == "bash_local" ]; then
            full_source_file_name="${STARTUP_DIR}/dotfiles/${source_prefix}/${source_file_name}"    
        else
            full_source_file_name="${STARTUP_DIR}/dotfiles/reference/${source_file_name}"    
        fi
    fi
    target_file_name="$HOME/.${source_file_name}"
    if [ -f ${full_source_file_name} ]; then
        if [ -f ${target_file_name} ]; then
            cp ${target_file_name} ${startup_backup_dir}
            rm -f ${target_file_name}
        fi
        ln -s ${full_source_file_name} ${target_file_name}
        chmod a+x ${target_file_name}
    else
        ln -s ${full_source_file_name} ${target_file_name}
        chmod a+x ${target_file_name}
    fi
}

mkdir -p ${STARTUP_DIR}
mkdir -p ${STARTUP_BACKUP_DIR}

cd ${STARTUP_DIR}

if ! [ -d bash-it ]; then
    git clone https://github.com/Bash-it/bash-it.git
else
    pushd bash-it
    git pull origin master
    popd
fi
if [ -f ${BOOTSTRAP_PERSONAL} ]; then
    if ! [ -d my-bash-it ]; then
        git clone git@github.com:tflynn/my-bash-it.git
    else
        pushd my-bash-it
        git pull origin master
        popd
    fi
    if ! [ -d dotfiles ]; then
        git clone git@github.com:tflynn/dotfiles.git
    else
        pushd dotfiles
        git pull origin master
        popd
    fi
    if ! [ -d mybin ]; then
        git clone git@github.com:tflynn/mybin.git
    else
        pushd mybin
        git pull origin master
        popd
    fi

    # Link startup files locally to host-based directory (as for today)
    source_prefix=$(hostname)
    link_startup_file "bash_env" "$source_prefix"
    link_startup_file "bashrc" "$source_prefix"
    link_startup_file "bash_aliases" "$source_prefix"
    link_startup_file "bash_local" "$source_prefix"
    link_startup_file "bash_profile" "$source_prefix"
else
    if ! [ -d my-bash-it ]; then
        git clone https://github.com/tflynn/my-bash-it.git
    else
        pushd my-bash-it
        git pull origin master
        popd
    fi
    if ! [ -d dotfiles ]; then
        git clone https://github.com/tflynn/public_dotfiles.git dotfiles
    else
        pushd dotfiles
        git pull origin master
        popd
    fi
    if ! [ -d mybin ]; then
        git clone https://github.com/tflynn/mybin.git
    else
        pushd mybin
        git pull origin master
        popd
    fi
    # Link startup files locally
    link_startup_file "bash_env"
    link_startup_file "bashrc"
    link_startup_file "bash_aliases"
    link_startup_file "bash_local"
    link_startup_file "bash_profile"
fi

# Link MYBIN to HOME/binp

function link_bin_file() {
    source_file=$1
    full_source_file="${STARTUP_DIR}/mybin/${source_file}"
    full_target_file="${HOME}/bin/${source_file}"
    if [ -e ${full_target_file} ]; then
        rm -f ${full_target_file}
    fi
    if ! [ -e ${full_target_file} ]; then
        ln -s ${full_source_file} ${full_target_file}
    fi
}

function link_bin_files() {
    for bin_file in $(ls -1 "$STARTUP_DIR/mybin")
    do
        link_bin_file ${bin_file}
    done
}

mkdir -p "$HOME/bin"
link_bin_files

# Enable useful aliases
source ${HOME}/.bash_profile
bash-it enable alias general git
bash-it enable plugin alias-completion base
my-bash-it enable alias general git osx python vagrant
my-bash-it enable plugin general git python sublime ttitle


