@info "Weekly entries selection"

# TODO: remplacer approximate_selection par un vrai dictionnaire d'intervales.
# Data
@load "data/exp_pro/approximate_selection.jld2" approximate_selection

# Constantes
const APPROXIMATE_SELECTION = approximate_selection::Dict{Int,Int}
const DFS = dfs::Dict{Int, DataFrame}
const MAX_FIRST_WEEKS_NB = 53::Int
# const GROUP_ID_VEC = @chain DFS keys collect # sort # Int[]
# const GROUP_ID_VEC = 12005 # first(GROUP_ID_VEC)::Int # INFO: pour les tests
const GROUP_ID_VEC = 11920 # first(GROUP_ID_VEC)::Int # INFO: pour les tests
const TAIL = ENTRIES[54:131]::Vector{Date}

approximate_selection[GROUP_ID_VEC]

# Variables
group_id::Int
group = Dict{Date,DataFrame}()

# Functions
## Microfonctions

function all_weeks_are_selected(
		group_id::Int;
		APPROXIMATE_SELECTION = APPROXIMATE_SELECTION,
		MAX_FIRST_WEEKS_NB = MAX_FIRST_WEEKS_NB,
		)::Bool
	APPROXIMATE_SELECTION[group_id] == MAX_FIRST_WEEKS_NB
end
@code_typed all_weeks_are_selected(0)

## Macrofonctions

# INFO: Vous avez des fonctions tests sur un petit échantillon de données sur `test/select_test.jl`

# INFO: Attention! Le type des entrées et des sorties de chaque fonction est indiqué lors de leur définition et assez souvent lors de leur appel. Cela permet de renseigner et de vérifier immédiatement les types, mais si des types doivent être changés, l'indication de type doit être changée partout.

# INFO:
# La fonction `select_subgroups` sélectionne toutes les semaines de la semaine 54 à la semaine 131, puis tente de sélectionner autant de semaines que possible depuis la semaine 1. Il teste différent nombres de semaines à partir d'un nombre de semaines probablement correct (APPROXIMATE_SELECTION): si le test réussit, il teste une semaine de plus jusqu'à échouer, et retient le dernier nombre de semaines qui a réussi; si le teste échoue, il teste une semaine de moins jusqu'à réussir, et retient le premier nombre de semaines qui réussit. create_subgroups déclenche une erreur s'il n'y a pas assez d'individus dans un sous-groupe, ce qui arrive nécessairement lorsqu'il y a trop de sous-groupes.

# function f(ALL_MONDAYS = ALL_MONDAYS)
#     ALL_MONDAYS
# end
# @code_typed f()
#
# function g()
#     ALL_MONDAYS
# end
# @code_typed g()

function select_subgroups(
		group_id::Int ;
		ENTRIES = ENTRIES,
		APPROXIMATE_SELECTION = APPROXIMATE_SELECTION,
		MAX_FIRST_WEEKS_NB = MAX_FIRST_WEEKS_NB,
		TAIL = TAIL,
		ALL_MONDAYS = ALL_MONDAYS,
		DFS = DFS,
		)::Dict{Date,DataFrame}
	# Variables intermédiaires
	head = ENTRIES[1:APPROXIMATE_SELECTION[group_id]]
	these_mondays = vcat(head, TAIL) # pas constant!
	# sortie
	group = Dict{Date,DataFrame}()
	try
		# group = create_subgroups(group_id, these_mondays, ALL_MONDAYS, ENTRIES, DFS)
		group = create_subgroups(group_id, these_mondays)
		# group = create_subgroups(group_id) # PERF: pas de différence de performance?
		# group = create_subgroups(12005, ENTRIES, vcat(ENTRIES[1:APPROXIMATE_SELECTION[12005]], TAIL), ALL_MONDAYS, DFS) # TEST:
		# group = create_subgroups(11920) # TEST:
		# @info "c'est OK"
		# @info "Vérité: $(all_weeks_are_selected(group_id))"
		# if APPROXIMATE_SELECTION[group_id] == MAX_FIRST_WEEKS_NB # OK:
		# if all_weeks_are_selected() # BUG: 
		if all_weeks_are_selected(group_id) # OK:
			@info "group_id = $group_id\nsubgroups total selection: [1:131]"
			return group
		else
			next_approximate_selection = APPROXIMATE_SELECTION[group_id] + 1
			for k = next_approximate_selection:MAX_FIRST_WEEKS_NB
				these_mondays = vcat(ENTRIES[1:k], TAIL)
				try
					# group = create_subgroups(group_id, these_mondays, ALL_MONDAYS, ENTRIES, DFS)
					group = create_subgroups(group_id, these_mondays)
					# group = create_subgroups(group_id) # PERF: beaucoup plus lent, parce que these_mondays change.
				catch
					@info "group_id = $group_id\nsubgroups selected from below: [1:$k, 54:131]"
					break
				end
			end
		end
	catch
		previous_approximate_selection = APPROXIMATE_SELECTION[group_id] - 1
		for k = previous_approximate_selection:-1:0
			these_mondays = vcat(ENTRIES[1:k], TAIL)
			try
				# group = create_subgroups(group_id, these_mondays, ALL_MONDAYS, ENTRIES, DFS)
				group = create_subgroups(group_id, these_mondays)
				# group = create_subgroups(group_id) # PERF: `these_mondays` change!
				@info "group_id = $group_id\nsubgroups selected from above: [1:$k, 54:131]"
				return group
			catch
			end
		end
	end
	return group
end
@code_typed select_subgroups()

function create_subgroups(
		# group_id::Int;
		# these_mondays = these_mondays,
		group_id::Int,
		these_mondays::Vector{Date};
		ALL_MONDAYS = ALL_MONDAYS,
		ENTRIES = ENTRIES,
		DFS = DFS,
	)::Dict{Date,DataFrame}
	# TEST: créée une vraie copie, pour les tests.
	pool = deepcopy(DFS[group_id])::DataFrame
	# pas une vraie copie = moins de mémoire, mais le dfs original 
	# est détruit en cours de route. Mais la consommation mémoire n'est 
	# pas la préoccupation majeure pour ce type de programme.
	# pool = dfs[group_id]
	# INFO: initialisation de la sortie
	group = Dict(
							 entry => DataFrame(
																	vaccinated = Bool[],
																	entry = Date[],
																	exit = Date[],
																	death = Date[],
																	DCCI = Vector{Tuple{Int,Date}}[],
																 ) for entry in ENTRIES
							)
	# INFO: agenda est un agenda qui indique à quelle date il faudra remplacer un non-vacciné A par un autre B, parce que le non-vacciné A se vaccine. Cet agenda indique également dans quels subroups sont les non-vaccinés à remplacer, et à quelles lignes. L'agenda est mis à jour à chaque ajout de non-vaccinés, c'est-à-dire à chaque itération de la boucle `in ALL_MONDAYS`.
	agenda = Dict{Date,Dict{Date,Vector{Int}}}()
	for this_monday in ALL_MONDAYS
		# INFO: traitement des vaccinés (qui ne sont jamais remplacés car ils ne se dévaccinent pas) et des premiers non-vaccinés (qui peuvent être remplacés parce qu'ils peuvent se vacciner). Écriture de l'agenda agenda pour y ajouter les non-vaccinés qui devront être remplacés, à quelles dates, dans quels sugroups et à quelles lignes.
		if this_monday in these_mondays
			subgroup = group[this_monday]
			# INFO: pour les vaccinés
			# Renvoie aussi le nombre de vaccinés dans chaque subgroup, car le nombre de vaccinés et de non-vaccinés doit être égal dans chaque group
			vaccinated_count = process_vaccinated!(
																						 pool::DataFrame,
																						 subgroup::DataFrame,
																						 this_monday::Date,
																						)::Int
			# Pour les premiers non-vaccinés
			process_first_unvaccinated!(
																	pool::DataFrame,
																	subgroup::DataFrame,
																	this_monday::Date,
																	vaccinated_count::Int,
																	agenda::Dict{Date,Dict{Date,Vector{Int}}},
																 )::Nothing
		end
		# Pour les non-vaccinés de remplacement
		# INFO: replace_unvaccinated!
		# À chaque `this_monday`, on ouvre l'agenda et on regarde ce qu'il y a à faire: quels non-vaccinés doivent être remplacés parce qu'ils se vaccinent. Les non-vaccinés sont remplacés exactement à leur date de vaccination et non avant, afin d'éviter les paradoxes où un évènement passé (le remplacement) est déterminé par un évènement futur (la vaccination). La fonction `replace_unvaccinated!` écrit aussi dans l'agenda lorsque des non-vaccinés de remplacement se vaccinent avant la fin de la période d'observation, afin de pouvoir les remplacer eux aussi lors d'itérations ultérieures de la boucle `in ALL_MONDAYS`.
		replace_unvaccinated!(
													this_monday::Date,
													pool::DataFrame,
													group::Dict{Date,DataFrame},
													agenda::Dict{Date,Dict{Date,Vector{Int}}},
												 )::Nothing
	end
	# INFO: filtrer seulement les dataframes qui contiennent des lignes:
	filter!(kv -> nrow(kv[2]) > 0, group)
	# TEST: renvoyer agenda avec group
	# return group, agenda
	return group
end
@code_typed create_subgroups()

function process_vaccinated!(pool::DataFrame, subgroup::DataFrame, this_monday::Date)::Int
	# INFO: Repérer dans `pool` les vaccinés du `subgroup` en cours, puis les mettre dans group[entry].
	for row in eachrow(pool)
		if row.dose1_week == this_monday
			vaccinated = true
			entry = this_monday
			exit = this_monday + Week(53) # INFO: un peu plus qu'un an, 53 semaines en tout
			death = row.death_week
			DCCI = [(row.DCCI, this_monday)] # INFO: un vecteur d'une paire (tuple)
			push!(
						subgroup,
						(
						 vaccinated = vaccinated,
						 entry = entry,
						 exit = exit,
						 death = death,
						 DCCI = DCCI,
						),
					 )
		end
	end
	# INFO:renvoie le nombre de vaccinés ajoutés à entry
	return nrow(subgroup)
end

function process_first_unvaccinated!(
		pool::DataFrame,
		subgroup::DataFrame,
		this_monday::Date,
		vaccinated_count::Int,
		agenda::Dict{Date,Dict{Date,Vector{Int}}},
	)::Nothing
	if vaccinated_count != 0
		eligible = findall( # TODO: envisager d'utiliser une fonction `eligible()` avec des paramètres par défaut variables qui sont évalués au moment de l'exécution, dont les valeurs réelles dépendront du contexte d'exécution (des valeurs des variables locales). Si `eligible()` est employé plusieurs fois, enregistrer sa valeur dans `eligible_out` plutôt que réexécuter eligible à chaque fois. si `eligible()` n'est exécuté qu'une seule fois, ça ne change rien.
											 row ->
											 # sont éligibles:
											 # les vivants:
											 this_monday <= row.death_week && # INFO: peuvent mourir la semaine courante de this_monday.
											 # non-vaccinés:
											 this_monday < row.dose1_week && # INFO: doivent être non-vaccinés la semaine courante
											 # qui ne sont pas encore dans un autre subgroup:
											 row.availability_week <= this_monday, # INFO: était auparavant `<`. Pourtant, plus bas: `pool[i, :availability_week] = exit + Week(1)`, ce qui signifie ces non-vaccinés sont disponibles un peu plus tôt, à partir de la semaine 54 et non 55. Mais est-ce que cela pose problème pour la toute première semaine, où la vaccination commence le dimanche 27 décembre 2020? En principe, non, car cela fait un décalage de 6 + 1.24 jours seulement. Il faut peut-être éclaircir le code au sujet des décalages des jours, car une année fait 52 semaines + 1.24 jours, et les vaccinations sont réputées commencer en milieu de semaines ou en fin en ce qui concerne la toute première semaine.
											 eachrow(pool),
											)
		if length(eligible) < vaccinated_count
			error(
						"$this_monday: Moins de non-vaccinés que de vaccinés pour entry = $this_monday",
					 )
			# INFO: cette erreur permet à la fonction `select_subgroups` de sélectionner le bon nombre de group.
		else
			# numéros de lignes, qui sont sélectionnées:
			# INFO: sélectionner, parmi les éligibles, le même nombre de non-vaccinés que de vaccinés.
			selected = sample(eligible, vaccinated_count, replace = false)
			for i in selected
				# INFO: Chaque ligne sélectionnée dans pool:
				row = pool[i, :]
				# INFO: un non-vaccinés sort soit à la fin de la subgroup, soit au moment de sa vaccination.
				vaccinated = false
				entry = this_monday
				exit = min(row.dose1_week, this_monday + Week(53))
				death = row.death_week
				DCCI = [(row.DCCI, this_monday)] # INFO: l'indice de comorbidités
				push!(
							subgroup,
							(
							 vaccinated = vaccinated, # vaccinated = false
							 entry = entry,
							 exit = exit,
							 death = death,
							 DCCI = DCCI,
							),
						 )
				# INFO: Un non-vacciné redevient disponible soit lorsqu'il est vacciné, soit lorsqu'il sort du subgroup. Attention, il pourrait être "disponible", après sa mort, d'où l'importance de vérifier si les non-vaccinés ne sont pas mort, avant d'intégrer ou de réintégrer une subgroup!
				pool[i, :availability_week] = exit + Week(1)
			end
		end
	end
	# INFO: Il faut ensuite noter dans l'agenda `agenda` les non-vaccinés qui devront être remplacés, et quand.
	# Itérateur sur les non-vaccinés à remplacer (when, what, where)
	# INFO: cet itérateur sélectionne le numéro de ligne, `this_monday` et `exit` de chaque non-vacciné à remplacer dans subroup, mais les réarange dans un autre sens: d'abord la date `exit` (car c'est à ce moment-là qu'il faudra le remplacer), puis `this_monday` (car c'est aussi l'identifiant du subgroup dans lequel le remplacement devra être fait) et le numéro de ligne (car c'est la ligne du non-vacciné à remplacer).
	when_what_where_iter = (
													(
													 row.exit, # Semaine de vaccination du non-vacciné: quand il faut s'occuper du remplacement
													 this_monday, # Identifiant (une date) du subgroup: dans quel subgroup a lieu le remplacement
													 i, # à quelle ligne
													) for (i, row) in enumerate(eachrow(subgroup))
													# INFO: On ne retient que les individus dont la durée (exit - entry) est strictement inférieure à 53 semaines, c’est-à-dire ceux qui se vaccinent avant la fin de la période d’observation. NOTA: cela exclut automatiqument les vaccinés, car dans leur cas, strictement: `(row.exit - row.entry) == Week(53)`
													if (row.exit - row.entry) < Week(53)
												 )
	# INFO: ajout de when_what_where_iter dans agenda
	# Cet agenda agenda est de type Dict{Date, Dict{Date, Vector{Int}}} où :
	# _when: (première date) quand faire le remplacement: au moment de la vaccination d'un non-vacciné,
	# _what: (deuxième date) dans quel subgroup faire le remplacement,
	# _where: (Vector{Int}) dans le subgroup, quels sont les numéros de ligne des non-vaccinés à remplacer.
	for (_when, _what, _where) in when_what_where_iter
		# INFO: Dans `agenda`: récupère (ou crée si absent) le dictionnaire interne associé à la date de vaccination du non-vacciné (_when).
		@chain begin
			# INFO: Chercher dans le dictionnaire `agenda` la clé `_when`. Si elle existe, retourner la valeur associée (un objet de type `Dict{Date, Vector{Int}}`); si elle n'existe pas, créer une paire `_when => valeur` dont la valeur est un objet vide de type `Dict{Date, Vector{Int}}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_dict`.
			agenda
			get!(_, _when, Dict{Date,Vector{Int}}())
			# INFO: Chercher dans le dictionnaire `inner_dict` la clé `_what`. Si elle existe, retourner la valeur associée (un objet de type Vector{Int}); si elle n'existe pas, créer une paire `clé => valeur` dont la valeur est un objet vide de type `Vector{Int}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_vector` (les lignes à changer, c'est-à-dire les non-vaccinés à remplacer, dans les `group`).
			get!(_, _what, Int[])
			# ajouter au vecteur `inner_vector` la valeur `_where`.
			append!(_, _where)
			# `agenda` a été mis à jour avec les nouvelles valeurs de `when_what_where_iter`.
		end
	end
	return nothing
end

function replace_unvaccinated!(
		this_monday::Date,
		pool::DataFrame,
		group::Dict{Date,DataFrame},
		agenda::Dict{Date,Dict{Date,Vector{Int}}},
	)::Nothing
	# rien à faire si aucun remplacement planifié pour this_monday
	if !haskey(agenda, this_monday)
		return nothing
	else
		_when = this_monday
		inner_dict = agenda[_when]
		# Les éligibles doivent être calculés de la même manière que dans chaque fonction `process_first_unvaccinated!`.
		eligible = findall(
											 row ->
											 # Sont éligibles, à la date de remplacement:
											 # les vivants:
											 _when <= row.death_week &&
											 # non-vaccinés:
											 _when < row.dose1_week &&
											 # qui ne sont pas encore dans un autre subgroup:
											 row.availability_week <= _when, # INFO: vérifier si c'est bien <= et non <
											 eachrow(pool),
											)
		for (_what, _where) in inner_dict
			if length(eligible) < length(_where)
				error(
							"$this_monday: Impossible replacement in $(_what)! `eligible` is lesser than `length(_where)`!",
						 )
			else
				selected = sample(eligible, length(_where), replace = false)
				for i in selected # INFO: `i` is each element of the `selected` vector.
					row = pool[i, :] # INFO: select all columns of line `i` of `pool`
					exit = min(row.dose1_week, _what + Week(53))
					pool[i, :availability_week] = exit + Week(1)
				end
				subgroup = group[_what]
				for (k, i) in enumerate(_where) # INFO: `i` have each `_where` value, and `k` is the range of `i` [1, 2, 3...].
					s = selected[k] # l'indice d'un individu de remplacement dans pool
					subgroup_end = _what + Week(53)
					vaccination_date = pool[s, :dose1_week] # sa date de vaccination (le cas échéant Date(1000,01,01), ce qui représente la non-vaccination)
					exit = min(subgroup_end, vaccination_date)
					death = pool[s, :death_week] # sa date de décès
					subgroup.exit[i] = exit # mettre la donnée dans subgroup
					subgroup.death[i] = death # mettre la donnée dans subgroup. Il n'est pas vraiment nécessaire de mettre à jour s'il ne s'agit pas du dernier non-vaccinés...
					push!(subgroup.DCCI[i], (pool[s, :DCCI], this_monday))
					if vaccination_date <= subgroup_end # Même chose que dans la fonction `process_first_unvaccinated`. `<=` ?
						@chain begin
							# dans agenda (un dictionnaire)
							agenda
							# récupérer la valeur de la clé `vaccination_date` (un dictionnaire)
							get!(_, vaccination_date, Dict{Date,Vector{Int}}())
							# dans ce dictionnaire, récupérer la valeur de la clé `_what` (un vecteur)
							get!(_, _what, Int[])
							# dans ce vecteur, ajouter la valeur de `i`.
							append!(_, i)
						end
					end
				end
			end
		end
	end
	return nothing
end

# # Processing
@time exact_selection =
ThreadsX.map(GROUP_ID_VEC) do group_id # PRODUCTION
	group_id => select_subgroups(group_id)
end |> Dict
exact_selection[GROUP_ID_VEC][Date("2020-12-21")]
# exact_selection[GROUP_ID_VEC][Date("2022-01-17")]

# INFO: pour vider la mémoire. Pas nécessaire.
# dfs = nothing

@info "Weekly entries selection completed"



# TEST:
@code_typed select_subgroups()
CodeInfo(
				 1 ─ %1 =    invoke
				 Main.:(var"#select_subgroups#128")(Main.ENTRIES::Vector{Date},
																						Main.APPROXIMATE_SELECTION::Dict{Int64, Int64},
																						Main.MAX_FIRST_WEEKS_NB::Int64,
																						Main.TAIL::Vector{Date},
																						Main.ALL_MONDAYS::Vector{Date},
																						Main.DFS::Dict{Int64, DataFrame},
																						#self#::typeof(select_subgroups), 0::Int64)::Dict{Date, DataFrame}
																						└──      return %1
																						) => Dict{Date, DataFrame}

# TEST:

@code_typed select_subgroups(0)
CodeInfo(
				 1 ─ %1 =    invoke
				 Main.:(var"#select_subgroups#128")(Main.ENTRIES::Vector{Date},
																						Main.APPROXIMATE_SELECTION::Dict{Int64, Int64},
																						Main.MAX_FIRST_WEEKS_NB::Int64,
																						Main.TAIL::Vector{Date},
																						Main.ALL_MONDAYS::Vector{Date},
																						Main.DFS::Dict{Int64, DataFrame},
																						#self#::typeof(select_subgroups), group_id::Int64)::Dict{Date, DataFrame}
																						└──      return %1
																						) => Dict{Date, DataFrame}

@code_typed create_subgroups(0)
CodeInfo(
1 ─ %1 =    invoke Main.:(var"#create_subgroups#121")(Main.these_mondays::Vector{Date},
Main.ALL_MONDAYS::Vector{Date},
Main.ENTRIES::Vector{Date},
Main.DFS::Dict{Int64, DataFrame},
#self#::typeof(create_subgroups),
group_id::Int64)::Dict{Date, DataFrame}
└──      return %1
) => Dict{Date, DataFrame}

