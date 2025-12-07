# Variables
unvaccinated = Date("10000-01-01")
still_alive = Date("10000-01-01")
available = Date("-10000-01-01")
unavailable = Date("10000-01-01")
first_monday = Date("2020-12-21")
last_monday = Date("2024-06-24")
mondays = collect(first_monday:Week(1):last_monday)
entries = first(mondays, length(mondays)-53)
subgroup_id = 11920
these_mondays = vcat(entries[1:8], entries[54:131])
Random.seed!(0)
weekly_entries = create_weekly_entries(entries, subgroup_id, these_mondays)
	# TODO return when_what_where_dict et autre chose?
