extends Control
    
func _ready() -> void:
    print("Solitaire gestartet!")

    var game_state := GameState.new()
    game_state.new_game()

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