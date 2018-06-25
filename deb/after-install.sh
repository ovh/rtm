#!/bin/bash
# check if we have a nvidia card on this host
if hash lshw 2>/dev/null; then
    echo "lshw found, checking if Nvidia card is present";
    SEARCH='display[ ]*NVIDIA|vendor: NVIDIA Corporation' # should match: display     NVIDIA Corporation
    TEST=`lshw -class display | grep -Ei "$SEARCH"`
    exit_status=$?
    if [ $exit_status -eq 0 ]; then 
        echo "Nvidia graphics cards found, installing metrics probes"
        if [ ! -d "/opt/noderig/60" ]; then
                mkdir -p /opt/noderig/60/
        fi
        if [ ! -f /opt/noderig/60/nvidia_smi_stats ]; then
                ln -s /usr/bin/nvidia_smi_stats /opt/noderig/60/nvidia_smi_stats
        fi
        if hash nvidia-smi 2>/dev/null; then
            echo "nvidia-smi driver found, install OK"
        else
            echo "nvidia-smi package not found, please install-it (and drivers) to get this probe working."
        fi
    else
        echo "no Nvidia graphics card found"
        # rm probe
        rm /usr/bin/nvidia_smi_stats
    fi  
elif hash lspci 2>/dev/null; then
    echo "lspci found, checking if Nvidia card is present" # lspci
    SEARCH='VGA compatible controller: NVIDIA|3D controller: NVIDIA' # should match: VGA compatible controller: NVIDIA
    TEST=`lspci | grep -Ei "$SEARCH"`
    exit_status=$?
    if [ $exit_status -eq 0 ]; then
        echo "Nvidia graphics cards found, installing metrics probes"
        if [ ! -d "/opt/noderig/60" ]; then
                mkdir -p /opt/noderig/60/
        fi
        if [ ! -f /opt/noderig/60/nvidia_smi_stats ]; then
                ln -s /usr/bin/nvidia_smi_stats /opt/noderig/60/nvidia_smi_stats
        fi
        if hash nvidia-smi 2>/dev/null; then
            echo "nvidia-smi driver found, install OK"
        else
            echo "nvidia-smi package not found, please install-it (and drivers) to get this probe working."
        fi
    else
        echo "no Nvidia graphics card found"
        rm /usr/bin/nvidia_smi_stats
    fi
else
    echo "lshw or lspci packages not found, please install them if you need nvidia metrics probe"
fi
