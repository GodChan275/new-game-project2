extends Node
## Static game data: waste categories, waste items, weapons, equipment, consumables.
## All player-facing names and descriptions are Thai.

enum Cat { ORGANIC = 0, HAZARDOUS = 1, GENERAL = 2, RECYCLABLE = 3 }

var cats := {
	Cat.ORGANIC: {
		"name": "ขยะเปียก", "th": "ขยะเปียก", "short": "เปียก", "en": "Organic Waste", "full": "Organic Waste",
		"bin": "bin_organic", "key": "organic", "icon": "bin_organic",
		"color": Color("4caf50"), "dark": Color("2e7d32"), "reward": 3,
		"hint": "เศษอาหาร เปลือกผลไม้ เศษผัก กากกาแฟ",
		"disposal": "เทลงถังขยะเปียก ปิดปากถุงให้มิดชิด แล้วนำไปหมักเป็นปุ๋ย",
		"why": "ขยะเปียกย่อยสลายได้เองตามธรรมชาติ จึงต้องแยกไปหมักทำปุ๋ยและไม่ปนกับขยะแห้ง"
	},
	Cat.HAZARDOUS: {
		"name": "ขยะอันตราย", "th": "ขยะอันตราย", "short": "อันตราย", "en": "Hazardous Waste", "full": "Hazardous Waste",
		"bin": "bin_hazard", "key": "hazardous", "icon": "bin_hazard",
		"color": Color("e67828"), "dark": Color("a4521a"), "reward": 12,
		"hint": "แบตเตอรี่ หลอดไฟ สารเคมี ขยะอิเล็กทรอนิกส์",
		"disposal": "แยกใส่กล่องปิดมิดชิด นำส่งจุดรับขยะอันตราย ห้ามทิ้งปนกับขยะทั่วไป",
		"why": "ขยะอันตรายมีสารพิษหรือโลหะหนัก ต้องกำจัดแบบพิเศษไม่ให้ปนลงดินและแหล่งน้ำ"
	},
	Cat.GENERAL: {
		"name": "ขยะทั่วไป", "th": "ขยะทั่วไป", "short": "ทั่วไป", "en": "General Waste", "full": "General Waste",
		"bin": "bin_general", "key": "general", "icon": "bin_general",
		"color": Color("4078c8"), "dark": Color("2a5590"), "reward": 4,
		"hint": "ซองเปื้อน กระดาษทิชชู่ ขยะปนกัน",
		"disposal": "ทิ้งลงถังขยะทั่วไป มัดปากถุงให้แน่นก่อนนำไปกำจัด",
		"why": "ขยะทั่วไปรีไซเคิลไม่ได้หรือเปื้อนอาหาร จึงต้องนำไปฝังกลบอย่างถูกสุขลักษณะ"
	},
	Cat.RECYCLABLE: {
		"name": "ขยะรีไซเคิล", "th": "ขยะรีไซเคิล", "short": "รีไซเคิล", "en": "Recyclable Waste", "full": "Recyclable Waste",
		"bin": "bin_recycle", "key": "recyclable", "icon": "bin_recycle",
		"color": Color("e8c832"), "dark": Color("b99a1c"), "reward": 8,
		"hint": "ขวด กระป๋อง กระดาษแข็งที่สะอาด",
		"disposal": "ล้างให้สะอาด พับให้แบน แล้วทิ้งลงถังรีไซเคิลเพื่อนำไปแปรรูปใหม่",
		"why": "ขยะรีไซเคิลที่สะอาดยังนำไปผลิตใหม่ได้ ลดการใช้ทรัพยากรและลดขยะฝังกลบ"
	},
}

var waste := {
	"banana_peel": {"name": "เปลือกกล้วย", "english_name": "Banana Peel", "cat": Cat.ORGANIC, "icon": "waste_banana", "weight": 0.8, "value": 0.9, "score": 10,
		"desc": "เปลือกผลไม้ ย่อยสลายได้ง่าย", "disposal": "ทิ้งในถังขยะเปียก หรือหมักทำปุ๋ยในหลุม"},
	"apple_core": {"name": "แกนแอปเปิล", "english_name": "Apple Core", "cat": Cat.ORGANIC, "icon": "waste_apple_core", "weight": 0.7, "value": 0.9, "score": 10,
		"desc": "เศษผลไม้เหลือทิ้ง", "disposal": "ทิ้งในถังขยะเปียก ไม่ควรปนกับของแห้ง"},
	"coffee_grounds": {"name": "กากกาแฟ", "english_name": "Coffee Grounds", "cat": Cat.ORGANIC, "icon": "waste_coffee", "weight": 0.9, "value": 1.0, "score": 10,
		"desc": "กากกาแฟพร้อมกระดาษกรอง", "disposal": "ทิ้งในถังขยะเปียก แล้วนำไปหมักต่อได้"},
	"food_scraps": {"name": "เศษอาหาร", "english_name": "Food Scraps", "cat": Cat.ORGANIC, "icon": "waste_cup", "weight": 1.0, "value": 1.0, "score": 10,
		"desc": "อาหารบูดเน่า ต้องทิ้งถังเปียก", "disposal": "เทเศษอาหารลงถังขยะเปียก ปิดฝาให้มิดชิด"},
	"dirty_wrapper": {"name": "ซองเปื้อนอาหาร", "english_name": "Food-Soiled Wrapper", "cat": Cat.GENERAL, "icon": "waste_wrapper", "weight": 1.0, "value": 1.0, "score": 8,
		"desc": "บรรจุภัณฑ์เปื้อนอาหาร รีไซเคิลไม่ได้", "disposal": "ทิ้งในถังขยะทั่วไป เพราะเศษอาหารปนเปื้อนรีไซเคิลไม่ได้"},
	"used_tissue": {"name": "กระดาษทิชชู่ใช้แล้ว", "english_name": "Used Tissue", "cat": Cat.GENERAL, "icon": "waste_tissue", "weight": 0.8, "value": 0.9, "score": 8,
		"desc": "ทิชชู่เปื้อน เชื้อโรคสูง", "disposal": "ทิ้งในถังขยะทั่วไป และล้างมือหลังทิ้ง"},
	"chip_bag": {"name": "ถุงขนม", "english_name": "Snack Wrapper", "cat": Cat.GENERAL, "icon": "waste_chipbag", "weight": 1.2, "value": 1.0, "score": 8,
		"desc": "ฟอยล์ผสมพลาสติก แยกยาก", "disposal": "ทิ้งในถังขยะทั่วไป เพราะฟอยล์ผสมพลาสติกแยกยาก"},
	"foam_cup": {"name": "ถ้วยโฟม", "english_name": "Foam Cup", "cat": Cat.GENERAL, "icon": "waste_cup", "weight": 1.1, "value": 1.0, "score": 8,
		"desc": "ถ้วยโฟมเปื้อนคราบอาหาร", "disposal": "ทิ้งในถังขยะทั่วไป อย่าใช้ซ้ำเมื่อมีคราบอาหาร"},
	"battery": {"name": "ถ่านไฟฉาย", "english_name": "Used Battery", "cat": Cat.HAZARDOUS, "icon": "waste_battery", "weight": 2.4, "value": 1.0, "score": 20,
		"desc": "ถ่านไฟฉายรั่ว ต้องสวมถุงมือ", "disposal": "ทิ้งในถังขยะอันตราย ห้ามปนกับขยะทั่วไปเพราะสารโลหะหนักอาจรั่ว"},
	"fluorescent_tube": {"name": "หลอดฟลูออเรสเซนต์", "english_name": "Fluorescent Tube", "cat": Cat.HAZARDOUS, "icon": "waste_tube", "weight": 2.0, "value": 1.1, "hard": true, "score": 20,
		"desc": "มีไอปรอท ต้องสวมถุงมือ", "disposal": "ห่อด้วยกระดาษกันแตก แล้วทิ้งในถังขยะอันตราย"},
	"chemical_can": {"name": "กระป๋องสารเคมี", "english_name": "Chemical Can", "cat": Cat.HAZARDOUS, "icon": "waste_chemcan", "weight": 2.6, "value": 1.2, "hard": true, "score": 20,
		"desc": "บรรจุภัณฑ์สารเคมีผุกร่อน", "disposal": "ปิดฝาให้แน่น นำส่งจุดรับขยะอันตราย ห้ามเทลงดินหรือท่อน้ำ"},
	"e_waste": {"name": "แผงวงจรอิเล็กทรอนิกส์", "english_name": "Electronic Waste", "cat": Cat.HAZARDOUS, "icon": "waste_circuit", "weight": 2.2, "value": 1.2, "hard": true, "score": 20,
		"desc": "มีโลหะหนัก ต้องสวมถุงมือ", "disposal": "ทิ้งในถังขยะอันตรายหรือจุดรับ e-waste เพื่อรีไซเคิลอย่างปลอดภัย"},
	"industrial_drum": {"name": "ถังอุตสาหกรรม", "english_name": "Industrial Drum", "cat": Cat.HAZARDOUS, "icon": "waste_drum", "weight": 3.4, "value": 2.0, "special": true, "score": 20,
		"desc": "ถังตะกอนสารพิษ ต้องใช้ชุดอุตสาหกรรม", "disposal": "ปิดผนึกด้วยชุดอุตสาหกรรม แล้วนำส่งศูนย์กำจัดของเสียอันตราย"},
	"plastic_bottle": {"name": "ขวดพลาสติก", "english_name": "Plastic Bottle", "cat": Cat.RECYCLABLE, "icon": "waste_bottle", "weight": 0.9, "value": 1.0, "score": 15,
		"desc": "ขวด PET ล้างสะอาดแล้ว", "disposal": "ล้าง บี้ให้แบน แล้วทิ้งในถังรีไซเคิล"},
	"glass_bottle": {"name": "ขวดแก้ว", "english_name": "Glass Bottle", "cat": Cat.RECYCLABLE, "icon": "waste_glass", "weight": 0.9, "value": 1.1, "score": 15,
		"desc": "ขวดแก้วสีเขียว รีไซเคิลได้", "disposal": "ล้างให้สะอาด ทิ้งในถังรีไซเคิล ระวังเศษแก้วบาด"},
	"aluminium_can": {"name": "กระป๋องอะลูมิเนียม", "english_name": "Aluminium Can", "cat": Cat.RECYCLABLE, "icon": "waste_can", "weight": 0.8, "value": 1.0, "score": 15,
		"desc": "กระป๋องเครื่องดื่มบี้แล้ว", "disposal": "ล้างและบี้ให้แบน แล้วทิ้งในถังรีไซเคิล"},
	"cardboard": {"name": "กล่องกระดาษ", "english_name": "Cardboard Box", "cat": Cat.RECYCLABLE, "icon": "waste_cardboard", "weight": 1.1, "value": 1.1, "score": 15,
		"desc": "กล่องแห้งที่พับแล้ว", "disposal": "พับให้แบนและให้แห้ง แล้วทิ้งในถังรีไซเคิล"},
	"newspaper": {"name": "กระดาษหนังสือพิมพ์", "english_name": "Newspaper", "cat": Cat.RECYCLABLE, "icon": "waste_newspaper", "weight": 1.0, "value": 1.0, "score": 15,
		"desc": "กระดาษแห้ง มัดรวมได้", "disposal": "มัดรวมให้แห้ง แล้วทิ้งในถังรีไซเคิล"},
	"orange_peel": {"name": "เปลือกส้ม", "english_name": "Orange Peel", "cat": Cat.ORGANIC, "icon": "waste_orange", "weight": 0.8, "value": 0.9, "score": 10,
		"desc": "เปลือกส้ม ย่อยสลายได้", "disposal": "ทิ้งในถังขยะเปียกเพื่อนำไปหมักทำปุ๋ย"},
	"vegetable_scraps": {"name": "เศษผัก", "english_name": "Vegetable Scraps", "cat": Cat.ORGANIC, "icon": "waste_veg", "weight": 0.9, "value": 0.9, "score": 10,
		"desc": "เศษผักและใบไม้จากครัว", "disposal": "ทิ้งในถังขยะเปียก มักทำปุ๋ยได้ทันที"},
	"light_bulb": {"name": "หลอดไฟ", "english_name": "Light Bulb", "cat": Cat.HAZARDOUS, "icon": "waste_bulb", "weight": 1.6, "value": 1.1, "hard": true, "score": 20,
		"desc": "หลอดแก้วแตกง่าย ต้องสวมถุงมือ", "disposal": "ทิ้งในถังขยะอันตราย ห่อด้วยกระดาษก่อนเพื่อไม่ให้แตก"},
	"foam_box": {"name": "กล่องโฟม", "english_name": "Foam Box", "cat": Cat.GENERAL, "icon": "waste_foambox", "weight": 1.0, "value": 1.0, "score": 8,
		"desc": "กล่องโฟมบรรจุอาหาร", "disposal": "ทิ้งในถังขยะทั่วไป เพราะโฟมเปื้อนอาหารรีไซเคิลไม่ได้"},
	"plastic_bag": {"name": "ถุงพลาสติกเปื้อนอาหาร", "english_name": "Plastic Bag with Food Residue", "cat": Cat.GENERAL, "icon": "waste_bag", "weight": 0.9, "value": 1.0, "score": 8,
		"desc": "ถุงเปื้อนน้ำมัน รีไซเคิลไม่ได้", "disposal": "ผูกปากถุงให้แน่น แล้วทิ้งในถังขยะทั่วไป"},
}

var weapons := {
	"baton": {
		"name": "กระบองเก็บขยะ", "icon": "baton", "price": 0,
		"damage": 11.0, "cooldown": 0.38, "reach": 38.0, "arc": 105.0, "stamina": 6.0,
		"desc": "อาวุธมาตรฐาน ใช้งานง่าย ตีไว"
	},
	"ion_baton": {
		"name": "กระบองไอออน", "icon": "ion_baton", "price": 260,
		"damage": 17.0, "cooldown": 0.31, "reach": 42.0, "arc": 115.0, "stamina": 7.0,
		"desc": "ใบมีดอาร์กชาร์จไฟ ตีไวและแรงขึ้น"
	},
	"servo_maul": {
		"name": "ค้อนเซอร์โว", "icon": "servo_maul", "price": 520,
		"damage": 34.0, "cooldown": 0.76, "reach": 54.0, "arc": 150.0, "stamina": 15.0,
		"desc": "ค้อนหนักพลังเซอร์โว แรงมากแต่ช้า"
	},
}

var equipment := {
	"shield": {"name": "โล่ป้องกัน", "icon": "shield", "price": 180,
		"desc": "ลดความเสียหายที่ได้รับ 30%", "stats": "ลดดาเมจ 30%"},
	"armor": {"name": "ชุดเกราะป้องกัน", "icon": "armor", "price": 220,
		"desc": "ชุดเสริมแรง เพิ่มพลังชีวิตสูงสุด 40", "stats": "+40 พลังชีวิต"},
	"flashlight": {"name": "ไฟฉาย", "icon": "flashlight", "price": 90,
		"desc": "ส่องสว่างในระยะบุกโจมตีตอนกลางคืน", "stats": "ลำแสงกว้าง"},
	"grabber": {"name": "ที่คีบขยะ", "icon": "grabber", "price": 70,
		"desc": "เพิ่มระยะเก็บขยะให้ไกลขึ้น", "stats": "+30 ระยะเก็บ"},
	"gloves": {"name": "ถุงมือกันสารพิษ", "icon": "gloves", "price": 110,
		"desc": "จำเป็นสำหรับขยะอันตรายและการทำความสะอาดคราบพิษ", "stats": "จับขยะอันตรายได้"},
	"bags": {"name": "ถุงเก็บขยะเสริม", "icon": "bags", "price": 90,
		"desc": "ถุงเสริมแรง รับขยะได้มากขึ้น", "stats": "+6 ช่องเก็บ"},
	"trolley": {"name": "รถเข็นเก็บขยะ", "icon": "trolley", "price": 180,
		"desc": "รถเข็นล้อเลื่อนสำหรับเดินเก็บขยะไกล ๆ", "stats": "+10 ช่องเก็บ"},
	"broom": {"name": "ไม้กวาดและที่ตัก", "icon": "broom", "price": 130,
		"desc": "กวาดขยะชิ้นเล็กได้ และคัดแยกทั้งหมดแม่นยำ", "stats": "คัดแยกสำเร็จ 100%"},
	"sort_container": {"name": "ถังคัดแยก", "icon": "sortbox", "price": 200,
		"desc": "ถังแยกประเภท ทำให้ได้เงินต่อชิ้นมากขึ้น", "stats": "+30% เงินคัดแยก"},
	"boots": {"name": "รองเท้ากันพิษ", "icon": "boots", "price": 120,
		"desc": "พื้นยางปิดสนิท ลดความเสียหายจากพื้นพิษครึ่งหนึ่ง", "stats": "-50% พิษ"},
	"mask": {"name": "หน้ากากกันพิษ", "icon": "mask", "price": 140,
		"desc": "กรองอากาศพิษ ลดความเสียหายเพิ่มอีก", "stats": "-35% พิษ"},
	"cart": {"name": "รถเข็นรีไซเคิล", "icon": "cart", "price": 240,
		"desc": "รถเข็นเฉพาะขยะรีไซเคิล เก็บได้มากขึ้นและได้เงินเพิ่ม", "stats": "+8 ช่องรีไซเคิล"},
	"industrial_kit": {"name": "ชุดจัดการขยะอุตสาหกรรม", "icon": "ikit", "price": 340,
		"desc": "ชุดปิดผนึกสำหรับถังและขยะอุตสาหกรรมหนัก", "stats": "จับถังพิษได้"},
}

var consumables := {
	"medkit": {"name": "ชุดปฐมพยาบาล", "icon": "medkit", "price": 25, "heal": 40.0,
		"desc": "พันแผลภาคสนาม ฟื้นฟู 40 HP"},
	"scrap": {"name": "เศษเหล็ก", "icon": "scrap", "price": 0, "heal": 0.0,
		"desc": "วัสดุที่เก็บได้ ขายได้เงินเล็กน้อย"},
}

const KINDS := ["waste", "weapon", "equipment", "consumable"]


func cat_info(c: int) -> Dictionary:
	return cats.get(c, cats[Cat.GENERAL])


func cat_name(c: int) -> String:
	return String(cat_info(c).get("th", "ขยะทั่วไป"))


func cat_name_en(c: int) -> String:
	return String(cat_info(c).get("en", "Waste"))


func cat_short(c: int) -> String:
	return String(cat_info(c).get("short", "ทั่วไป"))


func cat_icon(c: int) -> Texture2D:
	return Art.tex(String(cat_info(c).get("icon", "bin_general")))


func cat_disposal(c: int) -> String:
	return String(cat_info(c).get("disposal", ""))


func cat_why(c: int) -> String:
	return String(cat_info(c).get("why", ""))


func cat_key(c: int) -> String:
	return String(cat_info(c).get("key", "general"))


func cat_thai(c: int) -> String:
	return String(cat_info(c).get("th", "ขยะทั่วไป"))


func cat_bin_thai(c: int) -> String:
	return "ถัง" + cat_thai(c)


func cat_color(c: int) -> Color:
	return cat_info(c)["color"]


func bin_texture(c: int) -> String:
	return cat_info(c)["bin"]


func cat_from_bin_key(key: String) -> int:
	for c in cats.keys():
		if String(cats[c]["bin"]).ends_with(key):
			return c
	return Cat.GENERAL


func waste_def(id: String) -> Dictionary:
	return waste.get(id, waste["dirty_wrapper"])


func waste_cat(id: String) -> int:
	return int(waste_def(id)["cat"])


func waste_weight(id: String) -> float:
	return float(waste_def(id)["weight"])


func waste_icon(id: String) -> Texture2D:
	return Art.tex(String(waste_def(id)["icon"]))


func waste_en(id: String) -> String:
	return String(waste_def(id).get("english_name", id.capitalize()))


func waste_score(id: String) -> int:
	return int(waste_def(id).get("score", 10))


func waste_desc(id: String) -> String:
	return String(waste_def(id).get("desc", ""))


func waste_disposal(id: String) -> String:
	return String(waste_def(id).get("disposal", cat_disposal(waste_cat(id))))


func random_waste(cat: int = -1) -> String:
	var pool: Array = []
	for id in waste.keys():
		if cat < 0 or int(waste[id]["cat"]) == cat:
			pool.append(id)
	if pool.is_empty():
		return "dirty_wrapper"
	return String(pool[randi() % pool.size()])


func reward_base(cat: int) -> float:
	return float(cat_info(cat)["reward"])


## Returns {"kind":..., "id":..., "def":...} for any item id.
func find_item(id: String) -> Dictionary:
	if waste.has(id):
		return {"kind": "waste", "id": id, "def": waste[id]}
	if weapons.has(id):
		return {"kind": "weapon", "id": id, "def": weapons[id]}
	if equipment.has(id):
		return {"kind": "equipment", "id": id, "def": equipment[id]}
	if consumables.has(id):
		return {"kind": "consumable", "id": id, "def": consumables[id]}
	return {}


func item_name(id: String) -> String:
	var f := find_item(id)
	if f.is_empty():
		return id
	return String(f["def"]["name"])


func item_desc(id: String) -> String:
	var f := find_item(id)
	if f.is_empty():
		return ""
	return String(f["def"].get("desc", ""))


func item_icon(id: String) -> Texture2D:
	var f := find_item(id)
	if f.is_empty():
		return null
	var icon_name := String(f["def"].get("icon", "scrap"))
	if String(f["kind"]) == "waste":
		return Art.tex(icon_name)
	return Art.icon(icon_name)
