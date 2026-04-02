extends Node

# =========================
# SHOP MANAGER
# Persists shop state across shop panel visits on the same map
# Refreshes after boss / new map
# =========================

# -----------------------------------------------
# EASY TWEAK ZONE
# -----------------------------------------------
const SHOP_SIZE := 6
const HEALTH_PRICE := 3
const CHAOS_PRICE := 3
const HEALTH_PER_PURCHASE := 1
const CHAOS_RELIEF_PER_PURCHASE := 5
const HEALTH_LIMIT_PER_MAP := 5
const CHAOS_LIMIT_PER_MAP := 5
const BASE_REROLL_COST := 1
# Reset reroll cost on shop refresh — set false to carry over across maps
const RESET_REROLL_ON_REFRESH := true
# -----------------------------------------------

var shop_items: Array = []        # Array of ItemData or null (null = sold)
var reroll_cost := BASE_REROLL_COST
var health_bought_this_map := 0
var chaos_bought_this_map := 0
var is_initialized := false

var _rng := RandomNumberGenerator.new()


# =========================
# INITIALIZATION
# =========================

func refresh_shop(seed_value: int):
	_rng.seed = seed_value
	shop_items.clear()
	is_initialized = true
	health_bought_this_map = 0
	chaos_bought_this_map = 0

	if RESET_REROLL_ON_REFRESH:
		reroll_cost = BASE_REROLL_COST

	_populate_shop()


func _populate_shop():
	var pool = _build_weighted_pool()
	pool.shuffle()

	# Separate active and passive items
	var active_pool = pool.filter(func(i): return i.is_active)
	var passive_pool = pool.filter(func(i): return not i.is_active)

	shop_items.clear()

	# Place one guaranteed active item
	var guaranteed_active: ItemData = null
	if not active_pool.is_empty():
		guaranteed_active = active_pool.pop_front()

	# Fill remaining 5 slots from passive pool (and remaining actives)
	var remaining = passive_pool
	remaining.append_array(active_pool)
	remaining.shuffle()

	var selected: Array = []
	for i in range(min(SHOP_SIZE - 1, remaining.size())):
		selected.append(remaining[i])

	# Add guaranteed active at random position
	if guaranteed_active:
		var insert_pos = _rng.randi() % (selected.size() + 1)
		selected.insert(insert_pos, guaranteed_active)

	# Pad to SHOP_SIZE with nulls if needed
	while selected.size() < SHOP_SIZE:
		selected.append(null)

	shop_items = selected


func _build_weighted_pool() -> Array:
	var pool := []
	for item in ItemManager.all_items:
		var weight = _rarity_weight(item.rarity)
		for i in range(weight):
			pool.append(item)
	return pool


func _rarity_weight(rarity: int) -> int:
	match rarity:
		0: return 8   # Common
		1: return 4   # Uncommon
		2: return 2   # Rare
		3: return 1   # Legendary
	return 8


# =========================
# BUYING
# =========================

func buy_item(index: int) -> bool:
	if index < 0 or index >= shop_items.size():
		return false

	var item = shop_items[index]
	if item == null:
		return false

	if not RunProgressionManager.spend_dollars(item.price):
		return false

	ItemManager.give_item_by_name(item.item_name)
	shop_items[index] = null
	return true


func buy_health() -> bool:
	if health_bought_this_map >= HEALTH_LIMIT_PER_MAP:
		return false
	if not RunProgressionManager.spend_dollars(HEALTH_PRICE):
		return false
	health_bought_this_map += 1
	RunProgressionManager.add_health(HEALTH_PER_PURCHASE)
	return true


func buy_chaos_relief() -> bool:
	if chaos_bought_this_map >= CHAOS_LIMIT_PER_MAP:
		return false
	if not RunProgressionManager.spend_dollars(CHAOS_PRICE):
		return false
	chaos_bought_this_map += 1
	ChaosManager.cleanse_chaos(CHAOS_RELIEF_PER_PURCHASE)
	return true


func reroll() -> bool:
	if not RunProgressionManager.spend_dollars(reroll_cost):
		return false
	reroll_cost += 1
	_populate_shop()
	return true


func can_afford(price: int) -> bool:
	return RunProgressionManager.dollars >= price


func health_remaining() -> int:
	return HEALTH_LIMIT_PER_MAP - health_bought_this_map


func chaos_remaining() -> int:
	return CHAOS_LIMIT_PER_MAP - chaos_bought_this_map
