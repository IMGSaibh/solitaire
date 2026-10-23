## game_loss_analyzer.gd
## Findet nachträglich den Zug, ab dem eine Partie nicht mehr gewinnbar war -
## direkt aus GameService.undo_stack (das ihr für Undo sowieso schon führt,
## kein zusätzlicher Tracking-Code in game_controller.gd nötig).
##
## Kernidee: Lösbarkeit ist über eine Zugfolge monoton fallend - ist ein
## Zustand nicht mehr gewinnbar, kann kein späterer (davon abgeleiteter)
## Zustand wieder gewinnbar werden. Der Verlauf [lösbar, lösbar, ..., nicht
## lösbar, ..., nicht lösbar] erlaubt daher eine Binärsuche statt einer
## Solver-Prüfung nach jedem einzelnen Zug (O(log n) statt O(n) Aufrufe -
## bei langen Partien ein großer Performance-Gewinn).
##
## undo_stack[i] ist laut game_service.gd der Zustand VOR Zug (i+1), also
## gleichbedeutend mit "Zustand NACH Zug i" für i >= 1, und undo_stack[0]
## ist der Ausgangszustand (nach 0 Zügen). Der aktuelle game_service.state
## ist der Zustand nach dem letzten Zug. Zusammen ergibt das die komplette
## Zeitleiste.
class_name GameLossAnalyzer
extends RefCounted


## Baut die Snapshot-Zeitleiste [nach 0 Zügen, nach 1 Zug, ..., nach N Zügen].
static func build_snapshot_history(game_service: GameService) -> Array:
	var history: Array = []
	for snap in game_service.undo_stack:
		history.append(snap)
	history.append(game_service.state.create_snapshot())
	return history


## Index (0-basiert) des ERSTEN Zustands in der Snapshot-Zeitleiste, der laut
## Solver nicht mehr gewinnbar ist. history[index-1] war noch gewinnbar,
## history[index] nicht mehr -> Zug Nummer "index" (1-basiert) hat verloren.
## Gibt history.size() zurück, falls überraschenderweise alle Zustände noch
## lösbar erscheinen (Node-Budget zu knapp, oder das Spiel wurde fälschlich
## als verloren markiert).
static func find_first_unsolvable_index(snapshot_history: Array, node_budget: int = 300000, max_redeals: int = -1) -> int:
	var lo := 0
	var hi := snapshot_history.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		var state := CardCodec.state_from_snapshot(snapshot_history[mid])
		var solver := ThoughtfulSolver.new(node_budget, max_redeals)
		if solver.is_solvable_from_state(state):
			lo = mid + 1
		else:
			hi = mid
	return lo


## Komfortfunktion: nimmt direkt den GameService und liefert eine fertige
## Erklärung, sobald erkannt wurde, dass die Partie verloren ist
## (z. B. wenn game_service.can_auto_finish() false ist, keine Züge mehr
## möglich sind und game_state.is_game_won() false ist).
static func explain_loss(game_service: GameService, node_budget: int = 300000, max_redeals: int = -1) -> String:
	var history := build_snapshot_history(game_service)
	if history.size() < 2:
		return "Noch keine Züge gespielt."
	var idx := find_first_unsolvable_index(history, node_budget, max_redeals)
	if idx >= history.size():
		return "Laut Solver war die Partie bis zum Schluss noch gewinnbar."
	if idx == 0:
		return "Die Partie war schon zu Beginn nicht gewinnbar (Seed-Generierung prüfen)."
	return "Du hast verloren wegen: %s" % _describe_move(history[idx - 1], history[idx])


## Beschreibt, was sich zwischen zwei aufeinanderfolgenden Snapshots geändert
## hat. Einfache Heuristik über Pile-Größenänderungen - deckt Ziehen, Redeal
## und normale Einzel-/Lauf-Bewegungen ab. Bei mehreren gleichzeitig
## passenden Piles wird die erste gefundene genommen (Grenzfall, in der
## Praxis durch die Spielregeln aber eindeutig).
static func _describe_move(before: Dictionary, after: Dictionary) -> String:
	var before_stock: Array = before.get("stock", [])
	var after_stock: Array = after.get("stock", [])
	var before_waste: Array = before.get("waste", [])
	var after_waste: Array = after.get("waste", [])

	if after_stock.size() < before_stock.size() and after_waste.size() > before_waste.size():
		var drawn: Dictionary = after_waste[after_waste.size() - 1]
		return "Karte vom Stock gezogen: %s" % _card_label(drawn)

	if before_stock.is_empty() and not after_stock.is_empty() and not before_waste.is_empty() and after_waste.is_empty():
		return "Ablagestapel neu gemischt (Stock aufgefüllt)"

	var before_piles := _named_piles(before)
	var after_piles := _named_piles(after)

	var source_name := ""
	var moved_cards: Array = []
	for pile_name in before_piles.keys():
		var b: Array = before_piles[pile_name]
		var a: Array = after_piles[pile_name]
		if a.size() < b.size():
			source_name = pile_name
			moved_cards = b.slice(a.size(), b.size())
			break

	var target_name := ""
	for pile_name in after_piles.keys():
		var b2: Array = before_piles[pile_name]
		var a2: Array = after_piles[pile_name]
		if a2.size() > b2.size():
			target_name = pile_name
			break

	if moved_cards.is_empty() or source_name == "" or target_name == "":
		return "Unbekannter Zug"

	var labels: Array = []
	for c in moved_cards:
		labels.append(_card_label(c))
	return "%s von %s nach %s" % ["/".join(labels), source_name, target_name]


static func _named_piles(snapshot: Dictionary) -> Dictionary:
	var result := { }
	var foundations: Array = snapshot.get("foundations", [])
	for i in range(foundations.size()):
		result["Foundation %d" % (i + 1)] = foundations[i]
	var tableau: Array = snapshot.get("tableau", [])
	for i in range(tableau.size()):
		result["Tableau %d" % (i + 1)] = tableau[i]
	return result


static func _card_label(card_dict: Dictionary) -> String:
	var rank_names := { 1: "Ass", 11: "Bube", 12: "Dame", 13: "König" }
	var rank_val := int(card_dict.get("rank", 0))
	var rank_str: String = rank_names.get(rank_val, str(rank_val))
	var suit_names := ["Kreuz", "Karo", "Herz", "Pik"]
	var suit_val := int(card_dict.get("suit", 0))
	var suit_str: String = suit_names[suit_val] if suit_val >= 0 and suit_val < suit_names.size() else "?"
	return "%s %s" % [rank_str, suit_str]
