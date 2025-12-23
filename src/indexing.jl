@info "Indexing data"

dfs = Dict(
    parse(Int, string(first(df.sex), first(df."_5_years_cat_of_birth"))) => df
    for df in dfs
)

ThreadsX.foreach(df -> begin
									 select!(df.second, [:week_of_dose1, :week_of_death, :DCCI])
									 foreach(col -> replace!(col, missing => Date(10000,1,1)), eachcol(df.second))
									 insertcols!(df.second, 1, :available => Date(-10000,1,1))
								 end, dfs)

@info "Indexing completed"

