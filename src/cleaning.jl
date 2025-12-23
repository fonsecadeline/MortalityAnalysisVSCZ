@info "Cleaning dataframes"
ThreadsX.foreach(values(dfs)) do df
	# garantir l'absence de missing
	@assert all(!ismissing, df.week_of_dose1)
	@assert all(!ismissing, df.week_of_death)
	disallowmissing!(df, [:week_of_dose1, :week_of_death])
	# supprimer les incohérences temporelles
	filter!(r -> r.week_of_dose1 <= r.week_of_death ||
					r.week_of_dose1 == Date("10000-01-01"),
					df)
end
@info "Cleaning dataframes done"
