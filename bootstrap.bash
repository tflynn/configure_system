#!/usr/bin/env bash

DEBUG='false'
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
}

function update_if_debian_like() {
  if [ "$OS_TYPE" == 'debian' ]; then
    info "Running apt-get update"
    sudo apt-get update
  fi
}

function install_homebrew_and_cask_if_macos() {
  if [ $OS == 'macos' ]; then
    brew=$(which brew)
    if [ "$brew" == "" ]; then
       info "Installing Homebrew"
       /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
#       info "Installing homebrew cask"
#       brew tap caskroom/cask
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

function install_python3_pip3_if_missing() {
  python3=$(which python3)
  pip3=$(which pip3)
  if [ "$python3" != "" ] && [ "$pip3" != "" ]; then
    :
    # echo "python3 and pip3 already installed"
  else
    info "python3 or pip3 not installed. Trying to install both."
    if_macos && brew install python3
    if [ $OS_TYPE == 'debian' ]; then
      sudo apt-get -y install python3-pip
    fi
    python3=$(which python3)
    pip3=$(which pip3)
    if [ "$python3" == "" ] || [ "$pip3" == "" ]; then
      error "Problem with installation of python3 or pip3. Try to install manually and then rerun this script."
    fi
  fi
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

function install_ruby_if_missing() {

    if [ "$OS" == 'ubuntu' ]; then

        gcc=$(which gcc)
        if [ "$gcc" == "" ]; then
            info "Installing build tools etc"
            sudo apt-get install -y build-essential
        fi
        libssl=$(apt list --installed 2>&1 | grep -iv 'warning' | grep libssl-dev)
        if [ "$libssl" == "" ]; then
            info "Installing libssl-dev"
            sudo apt-get install -y libssl-dev
        fi
        libreadline=$(apt list --installed 2>&1 | grep -iv 'warning' | grep libreadline-dev)
        if [ "$libreadline" == "" ]; then
            info "Installing libreadline-dev"
            sudo apt-get install -y libreadline-dev
        fi
        zlib1g=$(apt list --installed 2>&1 | grep -iv 'warning' | grep zlib1g-dev)
        if [ "$zlib1g" == "" ]; then
            info "Installing zlib1g-dev"
            sudo apt-get install -y zlib1g-dev
        fi
    fi

    if [ "$OS" == 'macos' ]; then
        mas=$(which mas)
        if [ "$mas" == "" ]; then
            # Install mas
            info "Installing mas - Mac App Store command-line"
            brew install mas
        fi
        # Make sure Xcode is installed - gets gcc etc.
        xcode=$(mas list | grep -i xcode)
        if [ "$xcode" == "" ]; then
            # Requires existing GUI sign-on to AppStore
            # 497799835 Xcode (10.0)
            info "Installing Xcode from Mac App Store"
            mas install '497799835'
        fi
    fi

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

# TODO This could all go into the python-based portion of the installation

#function find_ansible_bin() {
#    ansible_bin=$(which ansible)
#    if [ -z "$ansible_bin" ]; then
#        ansible_find=$(sudo find / -name ansible)
#        if [ -n "$ansible_find"  ]; then
#            ansible_find=$(sudo find / -name ansible | grep bin)
#            if [ -n "$ansible_find" ]; then
#                echo $ansible_find
#            else
#                echo -n ""
#            fi
#        else
#            echo -n ""
#        fi
#    else
#        echo $ansible_bin
#    fi
#}
#
#function install_ansible_if_missing() {
#    if [ $DEBUG == 'true' ]; then
#        echo "install_ansible_if_needed PATH ${PATH}"
#        echo "install_ansible_if_needed python3 which $(which python3)"
#        echo "install_ansible_if_needed pip3 which $(which pip3)"
#    fi
#    ansible_bin=$(find_ansible_bin)
#    if [ -z "$ansible_bin" ]; then
#        # Force ansible to be installed using python3
#        pip3 install ansible
#        ansible_bin=$(find_ansible_bin)
#    fi
#    export ANSIBLE_BIN_DIR=$(dirname $ansible_bin)
#}
#
#function add_ansible_bin_to_path_if_missing() {
#    echo "$PATH" | grep "$ANSIBLE_BIN_DIR" > /dev/null
#    exit_code=$?
#    if [ "$exit_code" == "1" ]; then
#        export PATH="$PATH:$ANSIBLE_BIN_DIR"
#    fi
#    if [ -f $BASH_PROFILE ]; then
#        grep "$ANSIBLE_BIN_DIR" $BASH_PROFILE > /dev/null
#        exit_code=$?
#        if [ "$exit_code" == "1" ]; then
#            echo "export PATH=\"$PATH\"" >> $BASH_PROFILE
#        fi
#    else
#        echo "export PATH=\"$PATH\"" > $BASH_PROFILE
#    fi
#}


####
# Perform the installations in sequence
####

install_homebrew_and_cask_if_macos
force_update_yes_if_debian_like
update_if_debian_like
install_git_if_missing
install_python3_pip3_if_missing
#install_ansible_if_missing
#add_ansible_bin_to_path_if_missing
install_rbenv_if_missing
install_ruby_if_missing

# Restart to get everything as it should be
# Currently only do this on non-MacOS
if [ "$OS_TYPE" == 'debian' ]; then
    info "Signal reboot at the end of bootstrap process"
    touch ${BOOTSTRAP_REBOOT}
fi

curl -fsSL  https://raw.githubusercontent.com/tflynn/configure_system/master/bootstrap.dotfiles -o "${MY_TEMP}/bootstrap.dotfiles.bash"
chmod a+x "${MY_TEMP}/bootstrap.dotfiles"
source "${MY_TEMP}/bootstrap.dotfiles"
rm "${MY_TEMP}/bootstrap.dotfiles"

if [ "$OS" == 'macos' ]; then
    :
    # Run macos_installer
    curl -fsSL  https://raw.githubusercontent.com/tflynn/configure_system/master/bootstrap.macos_installer.bash -o "${MY_TEMP}/bootstrap.macos_installer.bash"
    # Do it this way to preserve the current environment
    source "${MY_TEMP}/bootstrap.macos_installer.bash"
    rm "${MY_TEMP}/bootstrap.macos_installer.bash"
fi

if [ "$OS_TYPE" == 'debian' ] && [ -f ${BOOTSTRAP_REBOOT} ]; then
    rm ${BOOTSTRAP_REBOOT}
    sudo reboot
fi
