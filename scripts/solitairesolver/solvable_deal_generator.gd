## solvable_deal_generator.gd
## Erzeugt aus einem Seed ein Array[CardData] (kompatibel zu GameService._deal_tableau
## / _fill_stock) und sucht per Rejection-Sampling einen Seed, dessen Deal laut
## ThoughtfulSolver lösbar ist.
##
## Empfehlung: find_solvable_seed() NICHT im Hauptthread bei jedem "Neues Spiel"
## aufrufen. Stattdessen z. B. beim Start der App per Thread einen Pool pro
## Schwierigkeitsstufe vorproduzieren (generate_seed_pool) und mit
## save_seed_pool()/load_seed_pool() cachen. new_game_from_seed() in GameService
## (siehe Patch weiter unten) liest dann nur noch einen fertigen Seed.
class_name SolvableDealGenerator
extends RefCounted


## Erzeugt das Deck für new_game_from_seed(): 52 CardData-Karten, verdeckt,
## in derselben Reihenfolge, wie sie GameService._deal_tableau()/_fill_stock()
## per pop_back() erwartet (also identisch zu deinem bisherigen
## `deck.shuffle()`, nur deterministisch aus dem Seed).
static func deck_from_seed(seed_value: int) -> Array[CardData]:
	var order := _seeded_shuffle_order(seed_value)
	var deck: Array[CardData] = []
	for id in order:
		var suit := CardCodec.suit_of(id) as CardData.Suit
		var rank := CardCodec.rank_of(id)
		deck.append(CardData.new(suit, rank, false))
	return deck


static func _seeded_shuffle_order(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array = []
	for i in range(52):
		ids.append(i)
	# Fisher-Yates-Shuffle: Jede Kartenpermutation ist gleich wahrscheinlich.
	# Durch den gesetzten Seed ist das Ergebnis trotzdem reproduzierbar.
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	return ids


## Legt eine Kartenreihenfolge (Array[int]-IDs) nach Klondike-Muster aus,
## exakt nach demselben pop_back()-Schema wie GameService._deal_tableau/_fill_stock,
## aber auf reinen ints statt CardData (für den schnellen Solver-Check ohne
## Objekt-Allokationen).
static func _deal_klondike_ids(order: Array) -> Dictionary:
	var deck := order.duplicate()
	var tableau: Array = []
	for col in range(GameState.TABLEAU_COUNT):
		var pile: Array = []
		for row in range(col + 1):
			pile.append(deck.pop_back())
		tableau.append(pile)
	var stock: Array = []
	while not deck.is_empty():
		stock.append(deck.pop_back())
	return { "tableau": tableau, "stock": stock }


## Sucht ab start_seed aufwärts den ersten Seed, dessen Deal lösbar ist.
## Rejection Sampling (Generate-and-Test): Kandidaten werden deterministisch
## erzeugt, vollständig vom Solver geprüft und bei fehlendem Lösungsbeweis
## verworfen. Nur ein Seed mit gefundenem Gewinnpfad wird akzeptiert.
## Gibt {} zurück, wenn innerhalb von max_attempts keiner gefunden wurde.
static func find_solvable_seed(start_seed: int, node_budget: int = 200000, max_attempts: int = 500, max_redeals: int = -1) -> Dictionary:
	var s := start_seed
	for attempt in range(max_attempts):
		var order := _seeded_shuffle_order(s)
		var deal := _deal_klondike_ids(order)
		var solver := ThoughtfulSolver.new(node_budget, max_redeals)
		var state := {
			"tableau": deal.tableau,
			"tableau_hidden": [0, 1, 2, 3, 4, 5, 6],
			"foundation": [0, 0, 0, 0],
			"stock": deal.stock,
			"waste": [],
			"redeals_used": 0,
			"draw_count": 1,
		}
		if solver.is_solvable_from_state(state):
			return { "seed": s, "nodes": solver.get_nodes_used(), "attempts": attempt + 1 }
		s += 1
	return { }


## Grobe Schwierigkeits-Heuristik anhand des Suchaufwands des Solvers.
## Die Anzahl besuchter Suchknoten dient dabei als Proxy-Metrik.
## Kein exaktes Maß für "menschliche" Schwierigkeit, nur ein brauchbarer Proxy.
static func classify_difficulty(nodes_used: int) -> String:
	if nodes_used < 500:
		return "easy"
	if nodes_used < 8000:
		return "medium"
	return "hard"


## Erzeugt einen Pool von n lösbaren Seeds pro Schwierigkeitsstufe.
## Für den Hintergrund-Thread gedacht (kann mehrere Sekunden dauern).
static func generate_seed_pool(seeds_per_difficulty: int, node_budget: int = 200000) -> Dictionary:
	var pool := { "easy": [], "medium": [], "hard": [] }
	var seed_cursor := randi()
	var safety_counter := 0
	while (
		(pool.easy.size() < seeds_per_difficulty or pool.medium.size() < seeds_per_difficulty or pool.hard.size() < seeds_per_difficulty)
		and safety_counter < 20000
	):
		safety_counter += 1
		var result := find_solvable_seed(seed_cursor, node_budget, 1)
		seed_cursor += 1
		if result.is_empty():
			continue
		var diff := classify_difficulty(result.nodes)
		if pool[diff].size() < seeds_per_difficulty:
			pool[diff].append({ "seed": result.seed, "nodes": result.nodes })
	return pool


## Speichert einen Seed-Pool als JSON (z. B. nach user://solvable_seeds.json).
static func save_seed_pool(path: String, pool: Dictionary) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(pool, "\t"))
	f.close()
	return OK


## Lädt einen zuvor gespeicherten Seed-Pool. Gibt {} zurück, falls nicht vorhanden.
static func load_seed_pool(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { }
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return { }
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	return data if data is Dictionary else { }
