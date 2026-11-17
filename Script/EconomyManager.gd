extends Node
## Money, XP and level. Single source of truth for player wealth.

signal money_changed(money: int, delta: int)
signal xp_changed(xp: int, level: int, needed: int)
signal leveled_up(level: int)

const START_MONEY := 60

var money: int = START_MONEY
var xp: int = 0
var level: int = 1
var total_earned: int = 0


func reset() -> void:
	money = START_MONEY
	xp = 0
	level = 1
	total_earned = 0
	money_changed.emit(money, 0)
	xp_changed.emit(xp, level, xp_needed())


func xp_needed() -> int:
	return 60 + (level - 1) * 45


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money = maxi(0, money + amount)
	if amount > 0:
		total_earned += amount
	money_changed.emit(money, amount)


func can_afford(amount: int) -> bool:
	return money >= amount


func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money, -amount)
	return true


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled_up.emit(level)
		Sfx.play("levelup")
	xp_changed.emit(xp, level, xp_needed())
