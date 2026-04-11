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
const HEALTH_PRICE := 2
const CHAOS_PRICE := 2
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

var purchased_item_names: Array = []
var purchased_slots: Array = []

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
	RunProgressionManager._seeded_shuffle(pool)

	var active_pool = pool.filter(func(i): return i.is_active)
	var passive_pool = pool.filter(func(i): return not i.is_active)

	var seen_names := []
	var unique_active := []
	for item in active_pool:
		if item.item_name not in seen_names:
			seen_names.append(item.item_name)
			unique_active.append(item)

	var unique_passive := []
	for item in passive_pool:
		if item.item_name not in seen_names:
			seen_names.append(item.item_name)
			unique_passive.append(item)

	var guaranteed_active: ItemData = null
	if not unique_active.is_empty():
		guaranteed_active = unique_active.pop_front()

	var remaining = unique_passive
	remaining.append_array(unique_active)
	remaining.shuffle()

	# Build new items only for non-purchased slots
	var available_slots := []
	for i in range(SHOP_SIZE):
		if i not in purchased_slots:
			available_slots.append(i)

	# Start with all nulls
	shop_items.resize(SHOP_SIZE)
	for i in range(SHOP_SIZE):
		shop_items[i] = null

	# Place guaranteed active in a non-purchased slot
	if guaranteed_active:
		var valid_positions = available_slots.duplicate()
		var insert_pos = valid_positions[_rng.randi() % valid_positions.size()]
		shop_items[insert_pos] = guaranteed_active
		available_slots.erase(insert_pos)

	# Fill remaining available slots
	var item_index := 0
	for slot in available_slots:
		if item_index >= remaining.size():
			break
		shop_items[slot] = remaining[item_index]
		item_index += 1




func _build_weighted_pool() -> Array:
	var pool := []
	var reward_pool_names = RunProgressionManager.reward_pool_items.map(func(i): return i.item_name)
	for item in ItemManager.all_items:
		if item.item_name in purchased_item_names:
			continue
		if item.item_name not in reward_pool_names:
			continue
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
	purchased_item_names.append(item.item_name)
	purchased_slots.append(index)
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
	if purchased_slots.size() >= 6:
		return false
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
