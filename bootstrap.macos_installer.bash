#!/usr/bin/env bash

my_temp="${HOME}/tmp"
export MY_TEMP=${MY_TEMP:-${my_temp}}

# Install required Python packages
pip3 install git+https://github.com/tflynn/standard_logger.git@master#egg=standard_logger
pip3 install git+https://github.com/tflynn/run_command.git@master#egg=run_command
pip3 install git+https://github.com/tflynn/macos_installer.git@master#egg=macos_installer

cat <<-RUN_INSTALLER > "${MY_TEMP}/run_macos_installer.py"
from macos_installer import installer
installer.main()
RUN_INSTALLER

python3 ${MY_TEMP}/run_macos_installer.py

rm  ${MY_TEMP}/run_macos_installer.py
