class_name SolvableDealPool
extends RefCounted

const CACHE_PATH := "user://solvable_seeds.json"
const TARGET_POOL_SIZE := 3
const NODE_BUDGET := 200000
const ATTEMPTS_PER_JOB := 25
const DIFFICULTIES := ["easy", "medium", "hard"]

var _pool := {"easy": [], "medium": [], "hard": []}
var _thread: Thread
var _next_seed := 0


func _init() -> void:
	_load_pool()
	_next_seed = int(Time.get_unix_time_from_system()) ^ randi()
	_start_generation_if_needed()


func update() -> void:
	_collect_finished_job()
	_start_generation_if_needed()


func take_seed() -> Dictionary:
	update()
	var available: Array[String] = []
	for difficulty in DIFFICULTIES:
		if not _pool[difficulty].is_empty():
			available.append(difficulty)
	if available.is_empty():
		return {}

	var difficulty := available[randi_range(0, available.size() - 1)]
	var entry: Dictionary = _pool[difficulty].pop_back()
	_save_pool()
	_start_generation_if_needed()
	return {
		"seed": int(entry.seed),
		"nodes": int(entry.nodes),
		"difficulty": difficulty,
	}


func is_generating() -> bool:
	return _thread != null


func shutdown() -> void:
	if _thread == null:
		return
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	_store_result(result)


func _load_pool() -> void:
	var loaded := SolvableDealGenerator.load_seed_pool(CACHE_PATH)
	for difficulty in DIFFICULTIES:
		var entries: Variant = loaded.get(difficulty, [])
		if entries is Array:
			for entry in entries:
				if entry is Dictionary and entry.has("seed") and entry.has("nodes"):
					_pool[difficulty].append(entry)


func _pool_size() -> int:
	var total := 0
	for difficulty in DIFFICULTIES:
		total += _pool[difficulty].size()
	return total


func _start_generation_if_needed() -> void:
	if _thread != null or _pool_size() >= TARGET_POOL_SIZE:
		return
	_thread = Thread.new()
	var start_seed := _next_seed
	_next_seed += ATTEMPTS_PER_JOB
	var error := _thread.start(_find_seed.bind(start_seed))
	if error != OK:
		push_error("Seed-Generator konnte nicht gestartet werden: %s" % error_string(error))
		_thread = null


func _collect_finished_job() -> void:
	if _thread == null or _thread.is_alive():
		return
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	_store_result(result)


func _store_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	var difficulty := SolvableDealGenerator.classify_difficulty(int(result.nodes))
	_pool[difficulty].append({"seed": int(result.seed), "nodes": int(result.nodes)})
	_save_pool()


func _save_pool() -> void:
	var error := SolvableDealGenerator.save_seed_pool(CACHE_PATH, _pool)
	if error != OK:
		push_warning("Lösbare Seeds konnten nicht gespeichert werden: %s" % error_string(error))


static func _find_seed(start_seed: int) -> Dictionary:
	return SolvableDealGenerator.find_solvable_seed(start_seed, NODE_BUDGET, ATTEMPTS_PER_JOB)
