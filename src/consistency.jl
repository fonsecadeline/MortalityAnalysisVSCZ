@info "Inconsistency: removing of people who died before their vaccination"
ThreadsX.foreach(values(exact_selection)) do df
	filter!(r -> r.entry <= r.death, df)
end
@info "Inconsistency: removing done"
