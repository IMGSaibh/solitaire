class_name GameState
extends RefCounted

var stock: CardPile
var waste: CardPile

var foundations: Array[CardPile] = []
var tableau: Array[CardPile] = []


func _init() -> void:
	_create_piles()


func _create_piles() -> void:
	stock = CardPile.new(CardPile.Type.STOCK)
	waste = CardPile.new(CardPile.Type.WASTE)

	for i in range(4):
		foundations.append(CardPile.new(CardPile.Type.FOUNDATION))

	for i in range(7):
		tableau.append(CardPile.new(CardPile.Type.TABLEAU))


func create_deck() -> Array[CardData]:
	var deck: Array[CardData] = []

	for suit in CardData.Suit.values():
		for rank in range(1, 14):
			var card := CardData.new(suit, rank, false)
			deck.append(card)

	return deck


func _clear_piles() -> void:
	stock.cards.clear()
	waste.cards.clear()

	for foundation in foundations:
		foundation.cards.clear()

	for pile in tableau:
		pile.cards.clear()


func _deal_tableau(deck: Array[CardData]) -> void:
	for column_index in range(7):
		for card_index in range(column_index + 1):
			var card: CardData = deck.pop_back()

			# Nur die letzte Karte jeder Spalte ist sichtbar
			card.face_up = card_index == column_index

			tableau[column_index].add_card(card)


func _fill_stock(deck: Array[CardData]) -> void:
	while not deck.is_empty():
		var card: CardData = deck.pop_back()
		card.face_up = false
		stock.add_card(card)


func new_game() -> void:
	_clear_piles()

	var deck := create_deck()
	deck.shuffle()

	_deal_tableau(deck)
	_fill_stock(deck)
