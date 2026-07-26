extends Control

func _ready() -> void:
    print("Solitaire gestartet!")
    var card := CardData.new(
        CardData.Suit.HEARTS,
        12,
        true
    )

    print(card.rank)
    print(card.get_rank_name())
    print(card.is_red())
    print(card.face_up)
