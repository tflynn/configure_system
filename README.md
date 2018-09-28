# configure_system
Configure a (new) system from scratch

## Requirements

For target systems

* Bash
* Standard tools - e.g. grep, cut, ...

If the target system is intended to be a personal system:

* Generate a suitable public/private key
* Load the public key in github
* Mark system as a personal system

    `touch ${HOME}/.bootstrap_personal`

## Intallation

```
curl -fsSL  https://raw.githubusercontent.com/tflynn/configure_system/master/bootstrap | bash -
```

'bootstrap' will:

* (macOS) Ensure homebrew is present
* (debian-like) Run package update
* Ensure git is present
* Ensure python3 and pip3 are present
* Ensure rbenv and ruby_build are present
* Ensure (recent) ruby is present (currently 2.5.1)
* Install standard and personal aliases via bash-it, my-bash-it, mybin
