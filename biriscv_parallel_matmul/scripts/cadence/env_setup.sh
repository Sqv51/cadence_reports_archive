#!/usr/bin/env bash
set -euo pipefail

# License server
export CDS_LIC_FILE="${CDS_LIC_FILE:-5280@100.75.31.67}"
export CDS_AUTO_64BIT=ALL

# Tool roots
export XCELIUM_ROOT="/eda/cadence/XCELIUM2509"
export GENUS_ROOT="/eda/cadence/DDI251/GENUS251"
export INNOVUS_ROOT="/eda/cadence/DDI251/INNOVUS251"

# PATH — use wrapper scripts (bin/) not raw binaries (tools.lnx86/)
# Wrappers manage LD_LIBRARY_PATH internally
export PATH="${GENUS_ROOT}/bin:${INNOVUS_ROOT}/bin:${XCELIUM_ROOT}/tools.lnx86/inca/bin:${PATH}"

# Genus needs this to find its technology kit
export CDN_SYNTH_ROOT="${GENUS_ROOT}/tools.lnx86"
export CDS_INST_DIR="${XCELIUM_ROOT}"
