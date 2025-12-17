@info "Adjust dates"
ThreadsX.foreach(values(exact_selection)) do df
    adjust_dcci_dates!(df)
end
@info "adjustment completed"

