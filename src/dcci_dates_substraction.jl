@info "DCCI: dates substraction"
ThreadsX.foreach(keys(exact_selection)) do k
	dcci_dates_substraction!(exact_selection[k])
end
ThreadsX.foreach(keys(exact_selection)) do k
    df = exact_selection[k]
    df.DCCI = [ [(Dates.value(d[1]), d[2]) for d in vec] for vec in df.DCCI ]
end
@info "DCCI: dates substraction completed"
