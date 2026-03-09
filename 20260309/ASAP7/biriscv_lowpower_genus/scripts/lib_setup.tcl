# =============================================================================
# Library and LEF Setup for ASAP7 (7nm) Low-Power Synthesis
# =============================================================================

set libdir "../../../../../Enablements/ASAP7/lib"
set lefdir "../../../../../Enablements/ASAP7/lef"
set qrcdir "../../../../../Enablements/ASAP7/qrc"

set_db init_lib_search_path [list $libdir $lefdir]

# Worst case library (used for setup timing and power analysis)
set libworst [glob ${libdir}/*.lib]

# Best case library (used for hold time optimization)
set libbest $libworst

# LEF files for physical information and macros
set lefs "
    ${lefdir}/asap7_tech_1x_201209.lef \
    ${lefdir}/asap7sc7p5t_27_R_1x_201211.lef \
    ${lefdir}/sram_asap7_16x256_1rw.lef \
    ${lefdir}/sram_asap7_32x256_1rw.lef \
    "

# QRC (Quantus RC) for parasitic extraction (max/min corners)
set qrc_max "${qrcdir}/ASAP7.tch"
set qrc_min "${qrcdir}/ASAP7.tch"

# Set design mode to 7nm process (Innovus command, may not be available in Genus)
catch {setDesignMode -process 7}
