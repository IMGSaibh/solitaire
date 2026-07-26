extends Control

var game_state: GameState

@onready var stock_view: PileView = $Board/Stock
@onready var waste_view: PileView = $Board/Waste

@onready var foundation_views: Array[PileView] = [
	$Board/Foundation1,
	$Board/Foundation2,
	$Board/Foundation3,
	$Board/Foundation4
]

@onready var tableau_views: Array[PileView] = [
	$Board/Tableau1,
	$Board/Tableau2,
	$Board/Tableau3,
	$Board/Tableau4,
	$Board/Tableau5,
	$Board/Tableau6,
	$Board/Tableau7
]

func _ready() -> void:
	print("Solitaire gestartet!")

	game_state = GameState.new()
	game_state.new_game()
	refresh_board()
	
	print("Stock: ", game_state.stock.size())

	for i in range(game_state.tableau.size()):
		print("---- Tableau ", i + 1)

		for card in game_state.tableau[i].cards:
			print(
				card.get_suit_name(),
				" ",
				card.get_rank_name(),
				" face_up=",
				card.face_up
			)

func refresh_board() -> void:
	stock_view.setup(game_state.stock)
	waste_view.setup(game_state.waste)

	for i in range(4):
		foundation_views[i].setup(
			game_state.foundations[i]
		)

	for i in range(7):
		tableau_views[i].setup(
			game_state.tableau[i]
		)
