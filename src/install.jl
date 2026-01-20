@info "Install packages"

import Pkg
Pkg.add([
    "Blake3Hash",
    "Chain",
    "CSV",
    "DataFrames",
		"DrWatson",
    "JLD2",
    "StatsBase",
    "ThreadsX",
])

@info "Packages installed"
