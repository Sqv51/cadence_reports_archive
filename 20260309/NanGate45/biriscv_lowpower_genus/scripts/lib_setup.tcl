# =============================================================================
# Library and LEF Setup for NanGate45 (45nm) Low-Power Synthesis
# =============================================================================

set libdir "../../../../../Enablements/NanGate45/lib"
set lefdir "../../../../../Enablements/NanGate45/lef"
set qrcdir "../../../../../Enablements/NanGate45/qrc"

set_db init_lib_search_path [list $libdir $lefdir]

# NanGate45 only has a typical corner library
# biRISC-V has no SRAMs, so no fakeram libs needed
set libworst " \
    ${libdir}/NangateOpenCellLibrary_typical.lib \
    "

set libbest " \
    ${libdir}/NangateOpenCellLibrary_typical.lib \
    "

# LEF files
set lefs " \
    ${lefdir}/NangateOpenCellLibrary.tech.lef \
    ${lefdir}/NangateOpenCellLibrary.macro.mod.lef \
    "

# QRC (Quantus RC) for parasitic extraction
set qrc_max "${qrcdir}/NG45.tch"
set qrc_min "${qrcdir}/NG45.tch"

# Set design mode to 45nm process
setDesignMode -process 45
