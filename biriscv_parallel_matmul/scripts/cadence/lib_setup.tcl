# NanGate45 lib/lef/qrc setup
set libdir "../../../../../Enablements/NanGate45/lib"
set lefdir "../../../../../Enablements/NanGate45/lef"
set qrcdir "../../../../../Enablements/NanGate45/qrc"

set_db init_lib_search_path [list $libdir $lefdir]

set libworst [list \
    ${libdir}/NangateOpenCellLibrary_typical.lib \
]

set libbest [list \
    ${libdir}/NangateOpenCellLibrary_typical.lib \
]

set lefs [list \
    ${lefdir}/NangateOpenCellLibrary.tech.lef \
    ${lefdir}/NangateOpenCellLibrary.macro.mod.lef \
]

set qrc_max "${qrcdir}/NG45.tch"
set qrc_min "${qrcdir}/NG45.tch"

set SITE "FreePDK45_38x28_10R_NP_162NW_34O"
set TOP_ROUTING_LAYER 10

setDesignMode -process 45
