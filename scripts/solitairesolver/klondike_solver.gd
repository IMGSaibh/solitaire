## klondike_solver.gd
## "Thoughtful Solitaire"-Solver für Klondike (volle Kenntnis aller Karten
## angenommen), passend zu deiner Regel-Implementierung in klondike_rules.gd
## (rank 1..13, leeres Tableau nur König, Foundation beginnt bei Ass, kein
## Redeal-Limit in recycle_waste() -> max_redeals default -1 = unbegrenzt,
## exakt wie dein GameService).
##
## Iterative Tiefensuche (kein Rekursions-Stack-Risiko) mit Node-Budget und
## Zustands-Cache gegen Zyklen. "solvable" ist konstruktiv bewiesen (echter
## Lösungspfad gefunden) -> keine falschen Positiv-Ergebnisse. "nicht lösbar"
## kann durch das Node-Budget oder die Vereinfachungen unten falsch-negativ
## sein, was für die Deal-Generierung unkritisch ist (nächster Seed probieren).
##
## Vereinfachungen (bewusst für Performance):
##  1. Keine Rückbewegung Foundation -> Tableau.
##  2. Tableau->Tableau bewegt nur den maximal gültigen, bereits aufgedeckten Lauf.
## Arbeitet mit den kompakten int-IDs aus CardCodec, nicht mit CardData direkt,
## damit die Suche keine Objekt-Allokationen pro Zustand braucht.
class_name ThoughtfulSolver
extends RefCounted

const RED_SUITS := [1, 2] # CardData.Suit.DIAMONDS, CardData.Suit.HEARTS

var node_budget: int
var max_redeals: int # -1 = unbegrenzt (wie dein GameService.recycle_waste())
var _visited: Dictionary
var _nodes: int


func _init(p_node_budget: int = 200000, p_max_redeals: int = -1) -> void:
	node_budget = p_node_budget
	max_redeals = p_max_redeals


## state-Format (siehe CardCodec für die Erzeugung):
## { tableau: Array[Array[int]], tableau_hidden: Array[int],
##   foundation: Array[int] (0..13, je Suit),
##   stock: Array[int], waste: Array[int], redeals_used: int, draw_count: int }
func is_solvable_from_state(state: Dictionary) -> bool:
	_visited = { }
	_nodes = 0
	var stack: Array = [state]
	while not stack.is_empty():
		var s: Dictionary = stack.pop_back()
		_nodes += 1
		if _nodes > node_budget:
			return false
		if _is_won(s):
			return true
		var key := _state_key(s)
		if _visited.has(key):
			continue
		_visited[key] = true
		for ns in _generate_moves(s):
			stack.push_back(ns)
	return false


func get_nodes_used() -> int:
	return _nodes


func _is_won(state: Dictionary) -> bool:
	for f in state.foundation:
		if f != 13:
			return false
	return true


func _is_red(id: int) -> bool:
	return CardCodec.suit_of(id) in RED_SUITS


func _state_key(state: Dictionary) -> String:
	var chunks: Array = [str(state.foundation), str(state.stock), str(state.waste), str(state.tableau_hidden)]
	for pile in state.tableau:
		chunks.append(str(pile))
	return "|".join(chunks)


func _can_place_on_tableau(pile: Array, id: int) -> bool:
	if pile.is_empty():
		return CardCodec.rank_of(id) == 13 # nur König auf leere Spalte
	var top: int = pile[pile.size() - 1]
	return CardCodec.rank_of(top) == CardCodec.rank_of(id) + 1 and _is_red(top) != _is_red(id)


func _can_place_on_foundation(foundation: Array, id: int) -> bool:
	var suit := CardCodec.suit_of(id)
	var rank := CardCodec.rank_of(id)
	if foundation[suit] == 0:
		return rank == 1
	return rank == foundation[suit] + 1


func _find_run_start(pile: Array, first_face_up: int) -> int:
	if pile.is_empty():
		return 0
	var start := pile.size() - 1
	while start > first_face_up:
		var a: int = pile[start - 1]
		var b: int = pile[start]
		if CardCodec.rank_of(a) == CardCodec.rank_of(b) + 1 and _is_red(a) != _is_red(b):
			start -= 1
		else:
			break
	return start


func _reveal_new_tableau_top(state: Dictionary, pile_index: int) -> void:
	var hidden_count: int = state.tableau_hidden[pile_index]
	if hidden_count > 0 and state.tableau[pile_index].size() == hidden_count:
		state.tableau_hidden[pile_index] = hidden_count - 1


func _generate_moves(state: Dictionary) -> Array:
	var moves: Array = []

	# 1. Tableau-Top -> Foundation
	for i in range(state.tableau.size()):
		var pile: Array = state.tableau[i]
		if pile.is_empty() or pile.size() <= int(state.tableau_hidden[i]):
			continue
		var id: int = pile[pile.size() - 1]
		if _can_place_on_foundation(state.foundation, id):
			var ns: Dictionary = state.duplicate(true)
			ns.tableau[i].pop_back()
			_reveal_new_tableau_top(ns, i)
			ns.foundation[CardCodec.suit_of(id)] = CardCodec.rank_of(id)
			moves.append(ns)

	# 2. Waste-Top -> Foundation
	if not state.waste.is_empty():
		var wid: int = state.waste[state.waste.size() - 1]
		if _can_place_on_foundation(state.foundation, wid):
			var ns2: Dictionary = state.duplicate(true)
			ns2.waste.pop_back()
			ns2.foundation[CardCodec.suit_of(wid)] = CardCodec.rank_of(wid)
			moves.append(ns2)

	# 3. Waste-Top -> Tableau
	if not state.waste.is_empty():
		var wid2: int = state.waste[state.waste.size() - 1]
		for i in range(state.tableau.size()):
			if _can_place_on_tableau(state.tableau[i], wid2):
				var ns3: Dictionary = state.duplicate(true)
				ns3.waste.pop_back()
				ns3.tableau[i].append(wid2)
				moves.append(ns3)

	# 4. Tableau -> Tableau (maximal gültiger, aufgedeckter Lauf)
	for i in range(state.tableau.size()):
		var pile2: Array = state.tableau[i]
		var first_face_up := int(state.tableau_hidden[i])
		if pile2.is_empty() or pile2.size() <= first_face_up:
			continue
		var run_start := _find_run_start(pile2, first_face_up)
		var run: Array = pile2.slice(run_start, pile2.size())
		for j in range(state.tableau.size()):
			if i == j:
				continue
			if _can_place_on_tableau(state.tableau[j], run[0]):
				var ns4: Dictionary = state.duplicate(true)
				ns4.tableau[i] = pile2.slice(0, run_start)
				ns4.tableau[j] = state.tableau[j] + run
				_reveal_new_tableau_top(ns4, i)
				moves.append(ns4)

	# 5. Stock -> Waste (ziehen) bzw. Waste -> Stock (Redeal)
	if not state.stock.is_empty():
		var n: int = min(int(state.get("draw_count", 1)), state.stock.size())
		var ns5: Dictionary = state.duplicate(true)
		for k in range(n):
			ns5.waste.append(ns5.stock.pop_back())
		moves.append(ns5)
	elif not state.waste.is_empty() and (max_redeals < 0 or state.redeals_used < max_redeals):
		var ns6: Dictionary = state.duplicate(true)
		ns6.stock = ns6.waste.duplicate(true)
		ns6.stock.reverse()
		ns6.waste = []
		ns6.redeals_used += 1
		moves.append(ns6)

	return moves
