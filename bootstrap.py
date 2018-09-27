#!/usr/bin/env python3

import subprocess


def run_command(**kwargs):
    """
    Run a command using Popen.
    Args:
        **kwargs: cmd=[command, params]

    Returns:
        Success: tuple of (out, err)
        Failure: None
    """

    # print(kwargs)
    if 'cmd' in kwargs:
        cmd = kwargs['cmd']
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        results = p.communicate()
        out = results[0].decode('UTF8').strip()
        err = results[1].decode('UTF8').strip()
        return (out,err)
    else:
        return None


if __name__ == "__main__":
    results = run_command(cmd=["pwd"])
    if results:
        out = results[0]
        print(out)

    results = run_command(cmd=["ls","-l"])
    if results:
        out = results[0]
        print(out)

