#!/usr/bin/env bash

DEBUG='false'
RUBY_VERSION="2.5.1"

# Presence of this file indicates whether this is a personal system
BOOTSTRAP_PERSONAL="${HOME}/.bootstrap_personal"

debug() {
  if [ $DEBUG == 'true' ]; then
    echo "DEBUG: $1"
  fi
}

info() {
    cat <<-HEADER

####

HEADER
    echo "$1"
    cat <<-FOOTER

####

FOOTER

}

error() {
        cat <<-HEADER

####

HEADER
    echo "$1"
    cat <<-FOOTER

####

FOOTER
    exit 1
}

# Distinction between "OS = ubuntu" and "OS_TYPE = debian"
# Any test that relies on particular packages being present uses 'OS = ubuntu'.
# Anything that is common to all debian-derived distributions uses "OS_TYPE = debian'.

if [[ $OSTYPE =~ ^darwin ]]; then
  OS=macos
elif [[ $OSTYPE =~ ^linux ]]; then
  OS_TYPE=""
  if [ -f /etc/debian_version ]; then
    id=$(cat /etc/os-release | grep '^ID=' )
    if [[ $id =~ ubuntu$ ]]; then
      OS=ubuntu
      UBUNTU_VERSION=$(cat /etc/*release | grep VERSION_ID | cut -d"=" -f2 | cut -d'"' -f2)
      if [ "$UBUNTU_VERSION" != "18.04" ]; then
        error "Only ubuntu 18.04 has been tested"
      fi
      OS_TYPE=debian
    else
      id_like=$(cat /etc/os-release | grep '^ID_LIKE=' )
      if [[ $id_like =~ debian$ ]]; then
        OS=debian
        OS_TYPE=debian
      fi
    fi
  fi
  if [ -z "$OS" ]; then
    error "Only ubuntu or debian-based systems are supported for installation"
  fi
else
  error "Only macos or linux are supported for installation"
fi

# Convenience methods
if_macos() { [ $OS == 'macos' ]; }
if_ubuntu() { [ $OS == 'ubuntu' ]; }
if_debian() { [ $OS == 'debian' ]; }

function remove_homebrew_if_macos() {
  if [ $OS == 'macos' ]; then
    brew=$(which brew)
    if ! [ "$brew" == "" ]; then
       info "Removing Homebrew"
       ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/remove)"
    fi
  fi
}

function remove_git() {
    git=$(which git)
    if ! [ "$git" == "" ]; then
        info "Removing git"
        if [ $OS == 'macos' ]; then
            brew remove git
        fi
        if [ "$OS" == 'ubuntu' ]; then
            sudo apt-get -y remove git
        fi
    fi
}

function remove_python3_pip3() {
  python3=$(which python3)
  pip3=$(which pip3)
  if [ "$python3" != "" ] && [ "$pip3" != "" ]; then
    info "Removing python3 and pip3"
    if_macos && brew remove python3
    if [ $OS_TYPE == 'debian' ]; then
      sudo apt-get -y remove python3-pip
    fi
    python3=$(which python3)
    pip3=$(which pip3)
    if [ "$python3" != "" ] || [ "$pip3" != "" ]; then
      error "Problem with removal of python3 or pip3. Try to remove manually and then rerun this script."
    fi
  fi
}

function remove_rbenv() {
    # Check for rbenv installation
    if [ -d ${HOME}/.rbenv ]; then
        info "Removing rbenv"
        rm -rf ${HOME}/.rbenv
    fi
}

function remove_dotfiles() {
    if [ -d ${HOME}/.startup ]; then
        info "Removing startup files"
        rm -rf ${HOME}/.startup
    fi
}

function remove_dead_links() {
    info "Removing dead links"
    find ${HOME}/bin -type l -exec unlink {} \;
}

function restore_startup_files() {
    if [ -d "${HOME}/.startup_backup" ]; then
        info "Restoring startup files from backup"
        backup_dir="${HOME}/.startup_backup/$(ls -1t ${HOME}/.startup_backup | head -n 1)"
        cp ${backup_dir}/.bash* ${HOME}
    fi
}

# removal sequence

# Make this harder for personal systems
if ! [ -f ${BOOTSTRAP_PERSONAL} ]; then
    remove_rbenv
    remove_dotfiles
    remove_dead_links
    restore_startup_files
    # remove_python3_pip3
    # remove_git
    # remove_homebrew_if_macos
fi
