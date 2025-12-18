#!/bin/bash
cd "$(dirname "$0")"
VARIANT=$1
echo "Running synthesis for variant: $VARIANT"
timeout 2400 genus -overwrite -log log/genus_${VARIANT}.log -no_gui -files run_genus.tcl
