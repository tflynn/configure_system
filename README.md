# configure_system
Configure a (new) system from scratch

## Requirements

For target systems

* Bash
* Standard tools - e.g. grep, cut, ...

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




