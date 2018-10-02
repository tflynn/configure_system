# configure_system

Configure a (new) system from scratch

## Intallation

```
curl -fsSL  https://raw.githubusercontent.com/tflynn/configure_system/master/bootstrap.bash | bash -
```

'bootstrap' will:

* (macOS) Ensure homebrew is present
* (debian-like) Run package update
* Ensure git is present
* Ensure python3 and pip3 are present
* Ensure rbenv and ruby_build are present
* Ensure (recent) ruby is present (currently 2.5.1)
* Backup your startup files
* Replace startup files with suitable versions to allow all these tools to work.
* Install and configure standard and personal aliases and utilities via:
    * [bash-it](https://github.com/Bash-it/bash-it)
    * [my-bash-it](https://github.com/tflynn/my-bash-it)
    * [mybin](https://github.com/tflynn/mybin)
    
Note that 'bootstrap' (and linked tools) can be rerun multiple times to fix problems, to force updates etc.
Just remember that startup files will be backed up and replaced on every run.

## Requirements

Really there aren't any requirements target systems, 
beyond what should be present on any basic *nix-like system. 

* Bash
* Standard tools - e.g. grep, cut, ...

If the target system is intended to be a personal system:

* Log into the Apple Store
* Generate a suitable public/private key
* Load the public key in github
* Mark system as a personal system

    `touch ${HOME}/.bootstrap_personal`

## Updates

To update aliases, binaries etc.:

  `update_startup`
  
## Removal

Copies of your original startup files are saved in:

  `${HOME}/.startup_backup/<datetamp>`
  
### Automatic

An experimental, largely untested script that automates removal can be run via:

```
curl -fsSL  https://raw.githubusercontent.com/tflynn/configure_system/master/unbootstrap.bash | bash -
```

This script has support for removing homebrew, git and python3/pip3, but that support is disabled.
 
### Manual

Some things are hard to remove, or probably should not be removed:

* (macOS) To remove homebrew

    `ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"`
    
* git, python3/pip3

    * macos - 'brew uninstall git python3'
    * debian/ubuntu - 'sudo apt-get remove git python3-pip'

To remove almost everything else:

* rbenv and ruby versions installed with rbenv

    `rm -rf ${HOME}/.rbenv`
    
    Remember to remove "${HOME}/.rbenv/shims" and "${HOME}/.rbenv/bin" from the PATH.
    
* bash_it, my_bash_it, mybin, dotfiles

    `rm -rf ~/.startup`

* mybin

  The previous step will remove all the utilities pointed to by "$HOME/bin", 
  but not the entries in "$HOME/bin". To remove those dangling links:
  
  `find ${HOME}/bin -type l -exec unlink {} \;` 
  
Finally, restore your original startup files:

`cp ${HOME}/.startup_backup/<datetamp>/.bash* ${HOME}`

Remember to restart your shell to see all the changes take effect.
