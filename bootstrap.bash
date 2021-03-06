#!/usr/bin/env bash

DEBUG='false'
VERSION="0.5"
RUBY_VERSION="2.5.1"
BASH_PROFILE="${HOME}/.bash_profile"


MY_TEMP="${HOME}/tmp"
mkdir -p ${MY_TEMP}

# Define reboot indicator
BOOTSTRAP_REBOOT="${HOME}/.bootstrap_reboot"
rm -f ${BOOTSTRAP_REBOOT}

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


if ! [[ $SHELL =~ bash$ ]]; then
  error "Only bash is supported for installation"
fi

info "Configure System (${VERSION})"

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

if [ $DEBUG == 'true' ]; then
  if_macos && debug "System is macos"
  if_ubuntu && debug "System is ubuntu"
  if_debian && debug "System is debian"
fi

if [ "$OS_TYPE" == 'debian' ]; then
  apt_bin=$(which apt-get)
  if [ "$apt_bin" == "" ]; then
    error "On debian-based systems, only 'apt-get' is supported for installation"
  fi
fi

# Only append to path if not present
function path_safe_append () {
  if ! echo "$PATH" | /bin/grep -Eq "(^|:)$1($|:)" ; then
    if [ "$2" = "before" ] ; then
      export PATH="$1:$PATH"
    else
      export PATH="$PATH:$1"
    fi
  fi
}

function force_update_yes_if_debian_like() {
    if [ "$OS_TYPE" == 'debian' ]; then
      # APT::Get::force-yes "true"; deprecated
      if ! [ -f /etc/apt/apt.conf.d/90forceyes ]; then
          info "Force all responses to apt-get prompts to 'yes'"
          sudo mkdir -p /etc/apt/apt.conf.d
          cat > 90forceyes <<-UPDATE_YES
  APT::Get::Assume-Yes "true";
UPDATE_YES
          sudo cp 90forceyes /etc/apt/apt.conf.d/90forceyes
          rm 90forceyes
      fi
    fi
}

function update_if_debian_like() {
  if [ "$OS_TYPE" == 'debian' ]; then
    info "Running apt-get update"
    sudo apt-get update
  fi
}

function add_user_as_sudoer() {
    # Create sudoers.d file in user space so substitutions are correct
    source_sudoers_file="${MY_TEMP}/${USER}.sudo"
    echo "${USER}  ALL=(ALL) NOPASSWD:ALL" > "${source_sudoers_file}"
    sudoers_d_directory="/etc/sudoers.d"
    sudo mkdir -p "${sudoers_d_directory}"
    target_sudoers_file="${sudoers_d_directory}/${USER}"
    sudo cp -f "${source_sudoers_file}" "${target_sudoers_file}"
    #sudo chown root:wheel "${target_sudoers_file}"
    sudo chmod 440 "${target_sudoers_file}"
}

function create_vimrc() {
  cat <<-VIMRC >${HOME}/.vimrc
syntax off
set nu
VIMRC
}

function install_homebrew_and_cask_if_macos() {
  if [ $OS == 'macos' ]; then
    brew=$(which brew)
    if [ "$brew" == "" ]; then
       info "Installing Homebrew"
       /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
       info "Installing homebrew cask"
       brew cask list
    fi
  fi
}

function install_git_if_missing() {
    git=$(which git)
    if [ "$git" == "" ]; then
        info "Installing git"
        if [ $OS == 'macos' ]; then
            brew install git
        fi
        if [ "$OS" == 'ubuntu' ]; then
            sudo apt-get -y install git
        fi
    fi
}

function install_pyenv_if_missing() {
  which pyenv
  if [ "$?" != "0" ]; then
    if [ -d "${HOME}/.pyenv" ]; then
      rm -rf "${HOME}/.pyenv"
    fi
    git clone https://github.com/pyenv/pyenv.git ${HOME}/.pyenv
  fi

  # In dotfiles/bash_env
  # Only here for bootstrap purposes
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bash_profile
  echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bash_profile
  echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.bash_profile
  source $BASH_PROFILE
}

function install_python3_pip3_if_missing() {
  # Install everything using pyenv  
  python=$(which python)
  pip=$(which python)
  if [ "$python" != "" ] && [ "$pip" != "" ]; then
    :
    # echo "python and pip already installed"
  else
    info "python or pip not installed. Trying to install both using pyenv."
    pyenv install 2.7.15
    python=$(which python)
    pip=$(which python)
    if [ "$python" == "" ] || [ "$pip" == "" ]; then
      error "Problem with installation of python or pip. Try to install manually and then rerun this script."
    fi
  fi
  # Set pyenv to point to python just installed
  pyenv global 2.7.15
  pip install --upgrade pip
  install_python_packages

  python3=$(which python3)
  pip3=$(which pip3)
  if [ "$python3" != "" ] && [ "$pip3" != "" ]; then
    :
    # echo "python3 and pip3 already installed"
  else
    info "python3 or pip3 not installed. Trying to install both using pyenv."
    pyenv install 3.6.5
    python3=$(which python3)
    pip3=$(which pip3)
    if [ "$python3" == "" ] || [ "$pip3" == "" ]; then
      error "Problem with installation of python3 or pip3. Try to install manually and then rerun this script."
    fi
  fi

    # Set pyenv to point to python just installed
  pyenv global 3.6.5
  pip install --upgrade pip
  install_python_packages
}

function install_python_packages() {
  pip install virtualenv
  pip install python-dateutil
}

function install_rbenv_if_missing() {

    # Check for rbenv installation
    if ! [ -d ${HOME}/.rbenv ]; then
        info "Installing rbenv"
        git clone https://github.com/rbenv/rbenv.git ${HOME}/.rbenv
    fi

    # Check for updated .bash_profile
    if ! [ -f $BASH_PROFILE ]; then
        touch $BASH_PROFILE
    fi
    grep '\$HOME/\.rbenv/bin' $BASH_PROFILE > /dev/null
    exit_code=$?
    if [ "$exit_code" == "1" ]; then
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> $BASH_PROFILE
    fi

    source $BASH_PROFILE
    # Initialize rbenv
    grep 'eval' $BASH_PROFILE > /dev/null
    exit_code=$?
    if [ "$exit_code" == "1" ]; then
        info "Updating .bash_profile to initialize rbenv"
        echo 'eval "$(rbenv init -)"' >> $BASH_PROFILE
    fi
    source $BASH_PROFILE
    # Install ruby-build as a ruby-env plugin
    if ! [ -d "$(rbenv root)/plugins/ruby-build" ]; then
        info "Installing ruby-build as a ruby-env plugin"
        mkdir -p "$(rbenv root)"/plugins
        git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
    fi

}

function install_mas_Xcode_if_macos_if_missing() {
    if [ "$OS" == 'macos' ]; then
        mas=$(which mas)
        if [ "$mas" == "" ]; then
            # Install mas
            # 2018/10/2 Note that MacOS Mojave 'mas login ...' and 'mas install ....' fails
            info "Installing mas - Mac App Store command-line"
            brew install mas
            # Force initialization of mas
            mas list
        fi
#        # Make sure Xcode is installed - gets gcc etc.
#        xcode=$(mas list | grep -i xcode)
#        if [ "$xcode" == "" ]; then
#            # Requires existing GUI sign-on to AppStore
#            # 497799835 Xcode (10.0)
#            info "Installing Xcode from Mac App Store"
#            mas install '497799835'
#        fi
    fi
}

function install_lib_if_ubuntu_if_missing() {
  lib_name="$1"
  lib_present=$(apt list --installed 2>&1 | grep -iv 'warning' | grep ${lib_name})
  if [ "$lib_present" == "" ]; then
    info "Installing ${lib_name}"
    sudo apt-get install -y ${lib_name}
  fi
}

function install_gcc_and_libs_if_ubuntu_if_missing() {

    if [ "$OS" == 'ubuntu' ]; then

        gcc=$(which gcc)
        if [ "$gcc" == "" ]; then
            info "Installing build tools etc"
            sudo apt-get install -y build-essential
        fi

        libs=('libssl-dev' 'libreadline-dev' 'zlib1g-dev' 'libbz2-dev' 'libsqlite3-dev')
        for lib in "${libs[@]}"
        do
          install_lib_if_ubuntu_if_missing $lib
        done

    fi
}

function install_ruby_if_missing() {

    ruby_bin=$(which ruby)
    if [ -z "$ruby_bin" ]; then
        info "Installing configured version of ruby using rbenv / rb_build"
        rbenv install $RUBY_VERSION
        rbenv rehash
        rbenv global $RUBY_VERSION
    else
        ruby_version=$(gem env | grep 'RUBY VERSION' | cut -d' ' -f6)
        if [ "$ruby_version" != "$RUBY_VERSION" ]; then
            info "Installing configured version of ruby using rbenv / rb_build"
            rbenv install $RUBY_VERSION
            rbenv rehash
            rbenv global $RUBY_VERSION
        fi
    fi
}

####
# Perform the installations in sequence
####

add_user_as_sudoer
create_vimrc
install_homebrew_and_cask_if_macos
force_update_yes_if_debian_like
update_if_debian_like
install_git_if_missing
install_mas_Xcode_if_macos_if_missing
install_gcc_and_libs_if_ubuntu_if_missing
install_rbenv_if_missing
install_ruby_if_missing
install_pyenv_if_missing
install_python3_pip3_if_missing
install_python_packages

# Signal reboot to get everything as it should be
# Currently only do this on non-MacOS
if [ "$OS_TYPE" == 'debian' ]; then
    info "Signal reboot at the end of bootstrap process"
    touch ${BOOTSTRAP_REBOOT}
fi

curl -fsSL  https://raw.githubusercontent.com/tflynn/configure_system/master/bootstrap.dotfiles.bash -o "${MY_TEMP}/bootstrap.dotfiles.bash"
chmod a+x "${MY_TEMP}/bootstrap.dotfiles.bash"
source "${MY_TEMP}/bootstrap.dotfiles.bash"
# rm "${MY_TEMP}/bootstrap.dotfiles.bash"

if [ "$OS" == 'macos' ]; then
    # Run macos_installer
    curl -fsSL  https://raw.githubusercontent.com/tflynn/configure_system/master/bootstrap.macos_installer.bash -o "${MY_TEMP}/bootstrap.macos_installer.bash"
    # Do it this way to preserve the current environment
    source "${MY_TEMP}/bootstrap.macos_installer.bash"
    rm "${MY_TEMP}/bootstrap.macos_installer.bash"
fi

# Restart to get everything as it should be
# Currently only do this on non-MacOS
if [ "$OS_TYPE" == 'debian' ] && [ -f ${BOOTSTRAP_REBOOT} ]; then
    rm ${BOOTSTRAP_REBOOT}
    sudo reboot
fi
