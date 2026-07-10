## BUILD MODE (The Sims): a full categorized catalog — seating, tables,
## storage, lighting, plants, decor, gadgets, FLOOR PAINT and WALLS.
## Click a card to spawn+carry (R rotate, X delete, Esc cancel), click a
## floor style then paint tiles one click at a time. Existing furniture
## can be picked up too. Everything persists to user:// and is re-applied
## on boot: moved pieces, deletions, purchases, painted floors.
class_name BuildMode
extends Node

## Layouts are PER OFFICE BRANCH — studio edits never leak into the
## factory floor and vice versa (the legacy shared file becomes the
## studio's on first load).
func _save_path() -> String:
	return "user://furniture_layout_%s.json" % Config.office_branch
const SNAP := 0.25

## kinds: chair/sofa/armchair/shelf = procedural office builders,
## prop = Office3D._prop (normalized fit), glb = native-scale model,
## wall = procedural partition, floor = tile paint style, special = the
## original packs. params._pal expands into the 12-colour PALETTE.
const CATALOG := [
	["cat_seat", [
		[{"th": "เก้าอี้เกมมิ่งแดง", "en": "Racing gaming chair"}, "special", {"id": "gaming_chair", "col": "c14b3f"}],
		[{"th": "เก้าอี้เกมมิ่งฟ้า", "en": "Racing gaming chair blue"}, "special", {"id": "gaming_chair", "col": "3fb8d9"}],
		[{"th": "เก้าอี้ผู้บริหารตาข่าย", "en": "High-back mesh chair"}, "special", {"id": "mesh_chair"}],
		[{"th": "เก้าอี้โยกไม้", "en": "Rocking chair"}, "special", {"id": "rocking_chair"}],
		[{"th": "เก้าอี้ไข่แขวน", "en": "Hanging egg chair"}, "special", {"id": "egg_swing"}],
		[{"th": "โซฟาเบด", "en": "Sofa bed"}, "special", {"id": "sofa_bed", "col": "55575c"}],
		[{"th": "เตียงสองชั้น", "en": "Bunk bed"}, "special", {"id": "bunk_bed"}],
		[{"th": "ม้านั่งเก็บของ", "en": "Storage bench"}, "special", {"id": "storage_bench"}],
		[{"th": "เก้าอี้ทำงาน", "en": "Task chair"}, "chair", {}],
		[{"th": "เลานจ์แชร์", "en": "Lounge chair"}, "glb", {"model": "loungeChair"}],
		[{"th": "โซฟาเลานจ์", "en": "Lounge sofa"}, "glb", {"model": "loungeSofa"}],
		[{"th": "เก้าอี้เบาะนวม", "en": "Cushion chair"}, "glb", {"model": "chairModernCushion"}],
		[{"th": "เก้าอี้ไม้", "en": "Chair"}, "glb", {"model": "chair"}],
		[{"th": "เก้าอี้โต๊ะทำงาน", "en": "Desk chair"}, "glb", {"model": "chairDesk"}],
		[{"th": "ม้านั่งเบาะ", "en": "Bench"}, "glb", {"model": "benchCushionLow"}],
		[{"th": "สตูลบาร์", "en": "Bar stool"}, "glb", {"model": "stoolBar"}],
		[{"th": "เก้าอี้คอทเทจ", "en": "Cottage chair"}, "glb", {"model": "kaykit/chair_A"}],
		[{"th": "เก้าอี้ไม้เข้ม", "en": "Wood chair"}, "glb", {"model": "kaykit/chair_A_wood"}],
		[{"th": "เก้าอี้หลังสูง", "en": "Tall chair"}, "glb", {"model": "kaykit/chair_B"}],
		[{"th": "สตูลไม้", "en": "Wood stool"}, "glb", {"model": "kaykit/chair_stool_wood"}],
		[{"th": "อาร์มแชร์หมอน", "en": "Pillow armchair"}, "glb", {"model": "kaykit/armchair_pillows"}],
		[{"th": "โซฟาหมอน", "en": "Pillow couch"}, "glb", {"model": "kaykit/couch_pillows"}],
		[{"th": "ม้านั่งไม้", "en": "Wood bench"}, "special", {"id": "bench_wood"}],
		[{"th": "สตูลบาร์ออฟฟิศ", "en": "Office bar stool"}, "special", {"id": "bar_office"}],
		[{"th": "เดย์เบด", "en": "Daybed"}, "special", {"id": "daybed"}],
		[{"th": "อาร์มแชร์ไม้ดัด", "en": "Bentwood chair"}, "special", {"id": "bentchair"}],
		[{"th": "สตูลบันได", "en": "Step stool"}, "special", {"id": "stepstool"}],
		[{"th": "เตียงนอน", "en": "Double bed"}, "special", {"id": "bed"}],
		[{"th": "โซฟา", "en": "Sofa"}, "sofa", {"_pal": 1}],
		[{"th": "อาร์มแชร์", "en": "Armchair"}, "armchair", {"_pal": 1}],
		[{"th": "เก้าอี้คาเฟ่", "en": "Cafe chair"}, "special", {"id": "cafe_chair", "_pal": 1}],
		[{"th": "บีนแบ็ก", "en": "Beanbag"}, "special", {"id": "beanbag", "_pal": 1}],
		[{"th": "ออตโตมัน", "en": "Ottoman"}, "special", {"id": "ottoman", "_pal": 1}],
		[{"th": "สตูลกลม", "en": "Round stool"}, "special", {"id": "stool_round", "_pal": 1}],
		[{"th": "เก้าอี้ปีก", "en": "Wingback"}, "special", {"id": "wing", "_pal": 1}],
		[{"th": "เก้าอี้เชลล์", "en": "Shell chair"}, "special", {"id": "shell", "_pal": 1}],
		[{"th": "เบาะรองนั่ง", "en": "Cushion"}, "special", {"id": "cushion", "_pal": 1}],
		[{"th": "โซฟาตัว L", "en": "L-sofa"}, "special", {"id": "sofa_l", "_pal": 1}],
	]],
	["cat_table", [
		[{"th": "โต๊ะข้างใบไม้", "en": "Leaf side table"}, "special", {"id": "leaf_table"}],
		[{"th": "โต๊ะขาหยั่ง", "en": "Trestle desk"}, "special", {"id": "trestle_desk"}],
		[{"th": "โต๊ะเกมมิ่ง RGB", "en": "RGB gaming desk"}, "special", {"id": "gaming_desk"}],
		[{"th": "โต๊ะเครื่องแป้งไฟฮอลลีวูด", "en": "Hollywood vanity"}, "special", {"id": "vanity", "col": "e0b4b8"}],
		[{"th": "โต๊ะกินข้าววงรีขยาย", "en": "Extendable oval table"}, "special", {"id": "ext_table"}],
		[{"th": "โต๊ะทำงาน", "en": "Desk"}, "glb", {"model": "desk"}],
		[{"th": "โต๊ะเข้ามุม", "en": "Corner desk"}, "glb", {"model": "deskCorner"}],
		[{"th": "โต๊ะอาหาร", "en": "Table"}, "glb", {"model": "table"}],
		[{"th": "โต๊ะกลม", "en": "Round table"}, "glb", {"model": "tableRound"}],
		[{"th": "โต๊ะกาแฟ", "en": "Coffee table"}, "glb", {"model": "tableCoffee"}],
		[{"th": "โต๊ะข้าง", "en": "Side table"}, "glb", {"model": "sideTable"}],
		[{"th": "โต๊ะข้างลิ้นชัก", "en": "Side drawers"}, "glb", {"model": "sideTableDrawers"}],
		[{"th": "โต๊ะเตี้ย", "en": "Low table"}, "glb", {"model": "kaykit/table_low"}],
		[{"th": "โต๊ะกลาง", "en": "Medium table"}, "glb", {"model": "kaykit/table_medium"}],
		[{"th": "โต๊ะยาว", "en": "Long table"}, "glb", {"model": "kaykit/table_medium_long"}],
		[{"th": "โต๊ะเล็ก", "en": "Small table"}, "glb", {"model": "kaykit/table_small"}],
		[{"th": "เคาน์เตอร์บาร์", "en": "Kitchen bar"}, "glb", {"model": "kitchenBar"}],
		[{"th": "ปลายเคาน์เตอร์", "en": "Bar end"}, "glb", {"model": "kitchenBarEnd"}],
		[{"th": "โต๊ะไม้โอ๊ค", "en": "Oak table"}, "special", {"id": "table_std", "top": "wood"}],
		[{"th": "โต๊ะขาว", "en": "White table"}, "special", {"id": "table_std", "top": "white"}],
		[{"th": "โต๊ะดำ", "en": "Black table"}, "special", {"id": "table_std", "top": "black"}],
		[{"th": "โต๊ะหินอ่อน", "en": "Marble table"}, "special", {"id": "table_std", "top": "marble"}],
		[{"th": "โต๊ะประชุมยาว 3 ม.", "en": "Long table 3m"}, "special", {"id": "table_std", "top": "wood", "w": 3.0, "d": 1.1}],
		[{"th": "โต๊ะคอนโซลผนัง", "en": "Console table"}, "special", {"id": "table_std", "top": "wood", "w": 1.2, "d": 0.35}],
		[{"th": "โต๊ะสี่เหลี่ยมเล็ก", "en": "Small square"}, "special", {"id": "table_std", "top": "white", "w": 0.8, "d": 0.8}],
		[{"th": "โต๊ะกระจก", "en": "Glass desk"}, "special", {"id": "desk_glass"}],
		[{"th": "โต๊ะผู้บริหาร", "en": "Executive desk"}, "special", {"id": "desk_exec"}],
		[{"th": "โต๊ะปิกนิก", "en": "Picnic table"}, "special", {"id": "picnic"}],
		[{"th": "โต๊ะพับ", "en": "Folding table"}, "special", {"id": "folding"}],
		[{"th": "โต๊ะทำงานออฟฟิศ", "en": "Office desk"}, "special", {"id": "desk_office"}],
		[{"th": "โต๊ะกลมออฟฟิศ", "en": "Office round table"}, "special", {"id": "round_office"}],
		[{"th": "โต๊ะปรับยืน", "en": "Standing desk"}, "special", {"id": "desk_stand"}],
		[{"th": "โต๊ะประชุม", "en": "Conference table"}, "special", {"id": "conftable"}],
		[{"th": "โต๊ะขาวมินิมอล", "en": "Frame desk"}, "special", {"id": "desk_scandi"}],
		[{"th": "โต๊ะกลมทิวลิป", "en": "Tulip table"}, "special", {"id": "tulip_table"}],
		[{"th": "โต๊ะข้างทรงกลอง", "en": "Drum table"}, "special", {"id": "drumtable"}],
		[{"th": "โต๊ะขาแฮร์พิน", "en": "Hairpin table"}, "special", {"id": "hairpin"}],
		[{"th": "โต๊ะถาดกลม", "en": "Tray table"}, "special", {"id": "traytable"}],
		[{"th": "โต๊ะตัว L", "en": "L-desk"}, "special", {"id": "desk_l", "_pal": 1}],
		[{"th": "โต๊ะลูกบาศก์", "en": "Cube table"}, "special", {"id": "side_cube", "_pal": 1}],
		[{"th": "โต๊ะกาแฟวงรี", "en": "Oval coffee"}, "special", {"id": "coffee_oval", "_pal": 1}],
		[{"th": "โต๊ะบาร์สูง", "en": "Bar table"}, "special", {"id": "table_bar", "_pal": 1}],
		[{"th": "โต๊ะคิวบ์", "en": "Side cube"}, "special", {"id": "cubeside", "_pal": 1}],
	]],
	["cat_store", [
		[{"th": "ตู้หนังสือสูงเต็มตู้", "en": "Tall bookcase (full)"}, "special", {"id": "billy"}],
		[{"th": "เพกบอร์ดครบชุด", "en": "Pegboard set"}, "special", {"id": "pegboard", "y": 1.3, "wall": 1}],
		[{"th": "ตู้กล่องสไลด์เด็ก", "en": "Slide-bin unit"}, "special", {"id": "trofast"}],
		[{"th": "ชั้นไม้สนสองช่วง", "en": "Pine bay shelving"}, "special", {"id": "ivar"}],
		[{"th": "ชั้นลวดโครเมียม", "en": "Chrome wire rack"}, "special", {"id": "wire_rack"}],
		[{"th": "ราวเสื้อ+ไม้แขวน", "en": "Clothes rail"}, "special", {"id": "clothes_rack"}],
		[{"th": "กล่องติดผนังสามใบ", "en": "Wall cube trio"}, "special", {"id": "eket_cubes", "y": 1.35, "wall": 1}],
		[{"th": "ชั้นหนังสือ", "en": "Bookshelf"}, "shelf", {}],
		[{"th": "ตู้หนังสือทึบ", "en": "Closed bookcase"}, "glb", {"model": "bookcaseClosedWide"}],
		[{"th": "ตู้หนังสือโปร่ง", "en": "Open bookcase"}, "glb", {"model": "bookcaseOpen"}],
		[{"th": "ตู้หนังสือเตี้ย", "en": "Low bookcase"}, "glb", {"model": "bookcaseOpenLow"}],
		[{"th": "ตู้ทีวี", "en": "TV cabinet"}, "glb", {"model": "cabinetTelevision"}],
		[{"th": "ตู้ครัว", "en": "Kitchen cabinet"}, "glb", {"model": "kitchenCabinet"}],
		[{"th": "ราวแขวนเสื้อ", "en": "Coat rack"}, "glb", {"model": "coatRackStanding"}],
		[{"th": "ตู้เล็ก", "en": "Small cabinet"}, "glb", {"model": "kaykit/cabinet_small"}],
		[{"th": "ตู้กลาง", "en": "Cabinet"}, "glb", {"model": "kaykit/cabinet_medium"}],
		[{"th": "ตู้แต่งลาย", "en": "Decorated cabinet"}, "glb", {"model": "kaykit/cabinet_medium_decorated"}],
		[{"th": "ชั้นใหญ่", "en": "Big shelf"}, "glb", {"model": "kaykit/shelf_A_big"}],
		[{"th": "ชั้นเล็ก", "en": "Small shelf"}, "glb", {"model": "kaykit/shelf_A_small"}],
		[{"th": "ชั้นโชว์ของ", "en": "Display shelf"}, "glb", {"model": "kaykit/shelf_B_large_decorated"}],
		[{"th": "กล่องเปิด", "en": "Open box"}, "prop", {"model": "cardboardBoxOpen", "fit": 0.5}],
		[{"th": "กล่องปิด", "en": "Sealed box"}, "prop", {"model": "cardboardBoxClosed", "fit": 0.55}],
		[{"th": "ถังขยะ", "en": "Trash can"}, "prop", {"model": "trashcan", "fit_h": 0.35}],
		[{"th": "ชั้นคิวบ์ 2×2", "en": "Cube shelf 2x2"}, "special", {"id": "shelf_cube", "n": 2}],
		[{"th": "ชั้นคิวบ์ 4×2", "en": "Cube shelf 4x2"}, "special", {"id": "shelf_cube", "n": 4}],
		[{"th": "ตู้เซฟ", "en": "Safe"}, "special", {"id": "safe"}],
		[{"th": "ชั้นลอยติดผนัง", "en": "Wall shelf"}, "special", {"id": "shelf_wall", "y": 1.4, "wall": 1}],
		[{"th": "กองลังไม้", "en": "Crate stack"}, "special", {"id": "crate_stack"}],
		[{"th": "ชั้นท่ออุตสาหกรรม", "en": "Pipe shelf"}, "special", {"id": "shelf_pipe"}],
		[{"th": "รถเข็นชั้นวาง", "en": "Utility cart"}, "special", {"id": "cart_roll"}],
		[{"th": "เครเดนซ่าออฟฟิศ", "en": "Office credenza"}, "special", {"id": "credenza_office"}],
		[{"th": "ตู้ลิ้นชัก 7 ชั้น", "en": "7-drawer unit"}, "special", {"id": "drawer7"}],
		[{"th": "ไซด์บอร์ดขาว", "en": "Sideboard"}, "special", {"id": "sideboard"}],
		[{"th": "ตะกร้าผ้า", "en": "Fabric basket"}, "special", {"id": "basket"}],
		[{"th": "ชั้นสตริงขาว", "en": "String shelf"}, "special", {"id": "string_shelf"}],
		[{"th": "ชั้นลอยขาว", "en": "Floating shelf"}, "special", {"id": "floatshelf", "col": "f0ede6", "y": 1.4, "wall": 1}],
		[{"th": "ตู้เอกสาร", "en": "File cabinet"}, "special", {"id": "file_cab", "n": 4, "_pal": 1}],
		[{"th": "ตู้เสื้อผ้า", "en": "Wardrobe"}, "special", {"id": "wardrobe", "_pal": 1}],
		[{"th": "ล็อกเกอร์", "en": "Lockers"}, "special", {"id": "locker", "_pal": 1}],
		[{"th": "กล่องพลาสติก", "en": "Plastic box"}, "special", {"id": "box_plastic", "_pal": 1}],
		[{"th": "ชั้นพิงผนัง", "en": "Ladder shelf"}, "special", {"id": "shelf_ladder", "_pal": 1}],
		[{"th": "ชั้นตาราง", "en": "Grid shelf"}, "special", {"id": "kallax", "_pal": 1}],
	]],
	["cat_light", [
		[{"th": "โคมโดมยักษ์", "en": "Grand dome lamp"}, "special", {"id": "dome_lamp"}],
		[{"th": "เสาไฟอัพไลท์", "en": "Uplight pole"}, "special", {"id": "uplight"}],
		[{"th": "ไฟห้อยหวายถัก", "en": "Woven pendant"}, "special", {"id": "weave_pendant"}],
		[{"th": "แชนเดอเลียร์ 6 แขน", "en": "Chandelier"}, "special", {"id": "chandelier"}],
		[{"th": "แถบไฟส่องผนัง", "en": "LED wall washer"}, "special", {"id": "cove_bar", "col": "8f5bff"}],
		[{"th": "โคมตั้งพื้นกลม", "en": "Floor lamp"}, "glb", {"model": "lampRoundFloor", "light": 1.4}],
		[{"th": "โคมตั้งพื้นสูง", "en": "Standing lamp"}, "glb", {"model": "kaykit/lamp_standing", "light": 1.5}],
		[{"th": "โคมโต๊ะเหลี่ยม", "en": "Table lamp"}, "glb", {"model": "lampSquareTable", "light": 0.5, "y": 0.74}],
		[{"th": "โคมโต๊ะ", "en": "Desk lamp"}, "glb", {"model": "kaykit/lamp_table", "light": 0.5, "y": 0.74}],
		[{"th": "ไฟราวเฟสตูน", "en": "String lights"}, "special", {"id": "string_lights"}],
		[{"th": "โคมโค้งตั้งพื้น", "en": "Arc lamp"}, "special", {"id": "lamp_arc"}],
		[{"th": "โคมสามขา", "en": "Tripod lamp"}, "special", {"id": "lamp_tripod"}],
		[{"th": "โคมกระดาษเล็ก", "en": "Lantern small"}, "special", {"id": "lantern", "s": 0.16}],
		[{"th": "โคมกระดาษใหญ่", "en": "Lantern big"}, "special", {"id": "lantern", "s": 0.26}],
		[{"th": "ซอฟต์บ็อกซ์", "en": "Softbox"}, "special", {"id": "softbox"}],
		[{"th": "ริงไลท์", "en": "Ring light"}, "special", {"id": "ring_light"}],
		[{"th": "ชุดเทียน", "en": "Candles"}, "special", {"id": "candles", "y": 0.74}],
		[{"th": "โคมแบงเกอร์", "en": "Banker lamp"}, "special", {"id": "banker", "y": 0.74}],
		[{"th": "โคมตั้งพื้นออฟฟิศ", "en": "Office floor lamp"}, "special", {"id": "lamp_office"}],
		[{"th": "โคมโต๊ะออฟฟิศ", "en": "Office task lamp"}, "special", {"id": "tasklamp_office", "y": 0.74}],
		[{"th": "ไฟห้อยออฟฟิศ", "en": "Office pendant"}, "special", {"id": "pendant_office"}],
		[{"th": "โคมกระดาษตั้งพื้น", "en": "Paper floor lamp"}, "special", {"id": "paperlamp"}],
		[{"th": "โคมลาวา", "en": "Lava lamp"}, "special", {"id": "lava", "y": 0.74}],
		[{"th": "ไฟห้อย", "en": "Pendant"}, "special", {"id": "pendant", "_pal": 1}],
		[{"th": "ไฟนีออน", "en": "Neon"}, "special", {"id": "neon_strip", "y": 1.4, "_pal": 1}],
		[{"th": "โคมแขนพับ", "en": "Task lamp"}, "special", {"id": "lamp_arm", "y": 0.74, "_pal": 1}],
		[{"th": "โคมเห็ด", "en": "Mushroom lamp"}, "special", {"id": "lamp_mushroom", "y": 0.74, "_pal": 1}],
	]],
	["cat_plant", [
		[{"th": "มาคราเม่แขวนสามกระถาง", "en": "Macrame trio"}, "special", {"id": "macrame_trio"}],
		[{"th": "มะกอกในตะกร้าหวาย", "en": "Olive in basket"}, "special", {"id": "olive_basket"}],
		[{"th": "บันไดสมุนไพร", "en": "Herb ladder"}, "special", {"id": "herb_ladder"}],
		[{"th": "สวนโหลแก้วครอบ", "en": "Glass cloche"}, "special", {"id": "cloche", "y": 0.74}],
		[{"th": "ต้นไม้กระถาง", "en": "Potted plant"}, "prop", {"model": "pottedPlant", "fit_h": 1.15}],
		[{"th": "ไม้กระถางเล็ก 1", "en": "Small plant 1"}, "glb", {"model": "plantSmall1"}],
		[{"th": "ไม้กระถางเล็ก 2", "en": "Small plant 2"}, "glb", {"model": "plantSmall2"}],
		[{"th": "ไม้แขวน", "en": "Hanging plant"}, "glb", {"model": "plantSmall3"}],
		[{"th": "กระบองเพชรเล็ก", "en": "Small cactus"}, "prop", {"model": "kaykit/cactus_small_A", "fit_h": 0.42}],
		[{"th": "กระบองเพชรกลาง", "en": "Cactus"}, "prop", {"model": "kaykit/cactus_medium_A", "fit_h": 0.6}],
		[{"th": "ปาล์มกระถาง", "en": "Palm"}, "special", {"id": "palm"}],
		[{"th": "เฟิร์นแขวน", "en": "Hanging fern"}, "special", {"id": "fern_hang", "y": 1.9}],
		[{"th": "ไผ่กวนอิม", "en": "Bamboo"}, "special", {"id": "bamboo"}],
		[{"th": "ต้นไม้ใหญ่ในอาคาร", "en": "Big indoor tree"}, "special", {"id": "bigtree"}],
		[{"th": "กระบะต้นไม้ยาว", "en": "Long planter"}, "special", {"id": "planter_long"}],
		[{"th": "บอนไซ", "en": "Bonsai"}, "special", {"id": "bonsai", "y": 0.74}],
		[{"th": "สมุนไพรครัว", "en": "Herb set"}, "special", {"id": "herbs", "y": 0.74}],
		[{"th": "สวนแนวตั้ง", "en": "Green wall"}, "special", {"id": "mosswall", "y": 1.2, "wall": 1}],
		[{"th": "กระบองเพชรยักษ์", "en": "Saguaro"}, "special", {"id": "saguaro"}],
		[{"th": "หญ้าแพมพาส", "en": "Pampas"}, "special", {"id": "pampas"}],
		[{"th": "พลูด่างกระถาง", "en": "Pothos"}, "special", {"id": "pothos", "y": 0.74}],
		[{"th": "ต้นไม้สนามใหญ่", "en": "Yard tree big"}, "special", {"id": "tree_office", "s": 1.2}],
		[{"th": "ต้นไม้สนามเล็ก", "en": "Yard tree small"}, "special", {"id": "tree_office", "s": 0.8}],
		[{"th": "พุ่มไม้", "en": "Bush"}, "special", {"id": "bush_office"}],
		[{"th": "ชั้นวางต้นไม้", "en": "Plant stand"}, "special", {"id": "plant_stand"}],
		[{"th": "ทิวลิปกระถาง", "en": "Tulip pot"}, "special", {"id": "tulip", "y": 0.74}],
		[{"th": "ขาตั้งต้นไม้", "en": "Plant pedestal"}, "special", {"id": "standscandi"}],
		[{"th": "แจกันดอกไม้", "en": "Flower vase"}, "special", {"id": "vase", "y": 0.74, "_pal": 1}],
		[{"th": "มอนสเตอร่ากระถางสี", "en": "Monstera pot"}, "special", {"id": "monstera", "_pal": 1}],
		[{"th": "ลิ้นมังกรกระถางสี", "en": "Snake plant pot"}, "special", {"id": "snake_plant", "_pal": 1}],
		[{"th": "ไทรกระถางสี", "en": "Ficus pot"}, "special", {"id": "ficus", "_pal": 1}],
	]],
	["cat_decor", [
		[{"th": "หิ้งรูปภาพพิง", "en": "Gallery ledge"}, "special", {"id": "gallery_ledge", "y": 1.45, "wall": 1}],
		[{"th": "ผ้าแขวนผนังทอ", "en": "Woven tapestry"}, "special", {"id": "tapestry", "y": 1.5, "wall": 1}],
		[{"th": "ลูกโลกบาร์วินเทจ", "en": "Globe bar"}, "special", {"id": "globe_bar"}],
		[{"th": "ป้ายนีออนหลอด", "en": "Neon tube sign"}, "special", {"id": "neon_open", "y": 1.6, "wall": 1}],
		[{"th": "ตู้ปลาทรงเสา", "en": "Column aquarium"}, "special", {"id": "column_aquarium"}],
		[{"th": "พรมผืนใหญ่", "en": "Area rug"}, "glb", {"model": "rugRectangle"}],
		[{"th": "พรมกลม", "en": "Round rug"}, "glb", {"model": "rugRound"}],
		[{"th": "พรมเหลี่ยม", "en": "Square rug"}, "glb", {"model": "rugSquare"}],
		[{"th": "พรมหน้าประตู", "en": "Doormat"}, "glb", {"model": "rugDoormat"}],
		[{"th": "พรมวงรี", "en": "Oval rug"}, "prop", {"model": "kaykit/rug_oval_A", "fit": 2.2}],
		[{"th": "พรมลายทาง", "en": "Striped rug"}, "prop", {"model": "kaykit/rug_rectangle_stripes_A", "fit": 2.4}],
		[{"th": "หมอนขาว", "en": "Pillow"}, "glb", {"model": "pillow"}],
		[{"th": "หมอนน้ำเงิน", "en": "Blue pillow"}, "glb", {"model": "pillowBlue"}],
		[{"th": "หมอนคอทเทจ", "en": "Cottage pillow"}, "glb", {"model": "kaykit/pillow_A"}],
		[{"th": "กองหนังสือ", "en": "Books"}, "glb", {"model": "books", "y": 0.74}],
		[{"th": "หนังสือตั้งโต๊ะ", "en": "Book set"}, "prop", {"model": "kaykit/book_set", "fit": 0.3, "y": 0.74}],
		[{"th": "กรอบรูปตั้งโต๊ะ", "en": "Standing frame"}, "prop", {"model": "kaykit/pictureframe_standing_A", "fit": 0.25, "y": 0.74}],
		[{"th": "กระจกพิงผนัง", "en": "Leaning mirror"}, "special", {"id": "mirror_stand"}],
		[{"th": "กระจกกลมแขวน", "en": "Round mirror"}, "special", {"id": "mirror_round", "y": 1.5, "wall": 1}],
		[{"th": "ที่กั้นหนังสือ", "en": "Bookends"}, "special", {"id": "bookends", "y": 0.74}],
		[{"th": "เครื่องหอม", "en": "Diffuser"}, "special", {"id": "diffuser", "y": 0.74}],
		[{"th": "ธงสามเหลี่ยม", "en": "Bunting"}, "special", {"id": "banner", "y": 1.7, "wall": 1}],
		[{"th": "ผนังรูปภาพ", "en": "Photo wall"}, "special", {"id": "photo_wall", "y": 1.4, "wall": 1}],
		[{"th": "บอร์ดรางวัล", "en": "Awards board"}, "special", {"id": "awards", "y": 1.4, "wall": 1}],
		[{"th": "ตู้ถ้วยรางวัล", "en": "Trophy case"}, "special", {"id": "trophy"}],
		[{"th": "นาฬิกาตั้งพื้น", "en": "Standing clock"}, "special", {"id": "clock"}],
		[{"th": "เก้าอี้หมุนไม้อ่อน", "en": "Swivel chair"}, "special", {"id": "chair_scandi"}],
		[{"th": "นาฬิกาแขวน", "en": "Wall clock"}, "special", {"id": "wallclock", "y": 1.45, "wall": 1}],
		[{"th": "นาฬิกา Flip", "en": "Flip clock"}, "special", {"id": "flipclock", "y": 0.74}],
		[{"th": "ลูกโลก", "en": "Globe"}, "special", {"id": "globe", "y": 0.74}],
		[{"th": "กระจกเต็มตัว", "en": "Full mirror"}, "special", {"id": "mirror_full"}],
		[{"th": "พรมลายเส้น", "en": "Line rug"}, "special", {"id": "rug_lines"}],
		[{"th": "ผ้าห่มพับ", "en": "Folded throw"}, "special", {"id": "throw", "y": 0.4}],
		[{"th": "บันไดแขวนผ้า", "en": "Blanket ladder"}, "special", {"id": "ladder"}],
		[{"th": "ราวแขวนผนัง", "en": "Hook rack"}, "special", {"id": "hookrack", "y": 1.5, "wall": 1}],
		[{"th": "เตาผิง", "en": "Fireplace"}, "special", {"id": "fireplace"}],
		[{"th": "ตู้ปลา", "en": "Aquarium"}, "special", {"id": "aquarium"}],
		[{"th": "พรมกลม", "en": "Round rug"}, "special", {"id": "rug_col", "_pal": 1}],
		[{"th": "ม่าน", "en": "Curtain"}, "special", {"id": "curtain", "_pal": 1}],
		[{"th": "แคนวาส", "en": "Canvas"}, "special", {"id": "art_canvas", "y": 1.3, "wall": 1, "_pal": 1}],
		[{"th": "ประติมากรรม", "en": "Sculpture"}, "special", {"id": "sculpture", "_pal": 1}],
		[{"th": "โปสเตอร์", "en": "Poster"}, "special", {"id": "poster", "y": 1.25, "wall": 1, "_pal": 1}],
		[{"th": "แจกันพื้นสูง", "en": "Floor vase"}, "special", {"id": "vase_floor", "_pal": 1}],
	]],
	["cat_gear", [
		[{"th": "ทีวี 75 นิ้ว+ซาวด์บาร์", "en": "TV 75in + soundbar"}, "special", {"id": "tv_wall", "y": 1.35, "wall": 1}],
		[{"th": "เครื่องเล่นแผ่นเสียง+แผ่น", "en": "Turntable set"}, "special", {"id": "turntable_set"}],
		[{"th": "ลำโพงปาร์ตี้ RGB", "en": "Party speaker"}, "special", {"id": "party_speaker"}],
		[{"th": "หุ่นยนต์ดูดฝุ่น+แท่น", "en": "Robot vacuum"}, "special", {"id": "robot_vac"}],
		[{"th": "โดรน+แท่นจอด", "en": "Drone pad"}, "special", {"id": "drone_pad", "y": 0.74}],
		[{"th": "มุม VR ครบชุด", "en": "VR station"}, "special", {"id": "vr_station"}],
		[{"th": "หม้อหุงข้าว", "en": "Rice cooker"}, "special", {"id": "rice_cooker", "y": 0.9}],
		[{"th": "หม้อทอดไร้น้ำมัน", "en": "Air fryer"}, "special", {"id": "air_fryer", "y": 0.9}],
		[{"th": "พัดลมตั้งพื้น", "en": "Stand fan"}, "special", {"id": "stand_fan"}],
		[{"th": "แอร์ติดผนัง", "en": "Wall air-con"}, "special", {"id": "aircon", "y": 2.05, "wall": 1}],
		[{"th": "ตู้แช่เครื่องดื่ม", "en": "Display drink fridge"}, "special", {"id": "drink_fridge"}],
		[{"th": "แล็ปท็อป", "en": "Laptop"}, "prop", {"model": "laptop", "fit": 0.32, "y": 0.74}],
		[{"th": "จอคอม", "en": "Monitor"}, "prop", {"model": "computerScreen", "fit_h": 0.38, "y": 0.74}],
		[{"th": "คีย์บอร์ด", "en": "Keyboard"}, "prop", {"model": "computerKeyboard", "fit": 0.28, "y": 0.74}],
		[{"th": "เมาส์", "en": "Mouse"}, "glb", {"model": "computerMouse", "y": 0.74}],
		[{"th": "ทีวีจอแบน", "en": "Television"}, "glb", {"model": "televisionModern", "y": 0.5}],
		[{"th": "ลำโพงตั้งพื้น", "en": "Speaker"}, "glb", {"model": "speaker"}],
		[{"th": "เครื่องชงกาแฟ", "en": "Coffee machine"}, "glb", {"model": "kitchenCoffeeMachine", "y": 0.9}],
		[{"th": "ตู้เย็นเล็ก", "en": "Small fridge"}, "glb", {"model": "kitchenFridgeSmall"}],
		[{"th": "จอคู่", "en": "Dual monitors"}, "special", {"id": "dual_mon", "y": 0.74}],
		[{"th": "จอโค้งอัลตร้าไวด์", "en": "Ultrawide"}, "special", {"id": "monitor_uw", "y": 0.74}],
		[{"th": "คอมออลอินวัน", "en": "All-in-one"}, "special", {"id": "aio", "y": 0.74}],
		[{"th": "เคส PC ไฟ RGB", "en": "RGB tower"}, "special", {"id": "pc_rgb"}],
		[{"th": "แล็ปท็อปบนแท่น", "en": "Laptop stand"}, "special", {"id": "laptop_stand", "y": 0.74}],
		[{"th": "เมาส์+แผ่นรอง", "en": "Mouse & pad"}, "special", {"id": "mouse_pad", "y": 0.74}],
		[{"th": "ไมค์พอดแคสต์", "en": "Podcast mic"}, "special", {"id": "mic", "y": 0.74}],
		[{"th": "แท่นวางหูฟัง", "en": "Headphones"}, "special", {"id": "headphone_stand", "y": 0.74}],
		[{"th": "เว็บแคมขาตั้ง", "en": "Webcam"}, "special", {"id": "webcam", "y": 0.74}],
		[{"th": "กล้องขาตั้งสูง", "en": "Camera tripod"}, "special", {"id": "tripod_cam"}],
		[{"th": "สตรีมเด็ค", "en": "Stream deck"}, "special", {"id": "streamdeck", "y": 0.74}],
		[{"th": "เมาส์ปากกา", "en": "Pen tablet"}, "special", {"id": "pen_tablet", "y": 0.74}],
		[{"th": "เครื่องพิมพ์ 3D", "en": "3D printer"}, "special", {"id": "printer3d", "y": 0.74}],
		[{"th": "โปรเจกเตอร์", "en": "Projector"}, "special", {"id": "projector", "y": 0.74}],
		[{"th": "จอโปรเจกเตอร์", "en": "Screen"}, "special", {"id": "proj_screen"}],
		[{"th": "เราเตอร์ WiFi", "en": "Router"}, "special", {"id": "router", "y": 0.74}],
		[{"th": "แท่นชาร์จมือถือ", "en": "Charging dock"}, "special", {"id": "charging_dock", "y": 0.74}],
		[{"th": "เครื่องเกมคอนโซล", "en": "Game console"}, "special", {"id": "console", "y": 0.5}],
		[{"th": "ลำโพงบูมบ็อกซ์", "en": "Boombox"}, "special", {"id": "boombox", "y": 0.74}],
		[{"th": "ฉากกรีนสกรีน", "en": "Green screen"}, "special", {"id": "greenscreen"}],
		[{"th": "ตู้เซิร์ฟเวอร์", "en": "Server rack"}, "special", {"id": "server"}],
		[{"th": "ปรินเตอร์", "en": "Printer"}, "special", {"id": "printer", "y": 0.74}],
		[{"th": "แท่นวางจอ", "en": "Monitor riser"}, "special", {"id": "monstand", "y": 0.74}],
		[{"th": "ทีวีย้อนยุค", "en": "Retro TV"}, "special", {"id": "crt"}],
		[{"th": "แผ่นรองโต๊ะ", "en": "Desk mat"}, "special", {"id": "desk_mat", "y": 0.74, "_pal": 1}],
		[{"th": "คีย์บอร์ดเรืองแสง", "en": "RGB keyboard"}, "special", {"id": "kb_rgb", "y": 0.74, "_pal": 1}],
	]],
	["cat_office", [
		[{"th": "เคาน์เตอร์แคชเชียร์ POS", "en": "POS counter"}, "special", {"id": "pos_counter"}],
		[{"th": "ชั้นสินค้าสองหน้า", "en": "Gondola shelf"}, "special", {"id": "gondola"}],
		[{"th": "เสากั้นคิว+สาย", "en": "Queue barrier"}, "special", {"id": "queue_barrier"}],
		[{"th": "ครัวมินิ ซิงค์+เตา", "en": "Kitchenette"}, "special", {"id": "kitchenette"}],
		[{"th": "บูธเงียบ", "en": "Focus booth"}, "special", {"id": "booth"}],
		[{"th": "ตู้กดน้ำ", "en": "Water cooler"}, "special", {"id": "cooler"}],
		[{"th": "ตู้ขายของ", "en": "Vending machine"}, "special", {"id": "vending"}],
		[{"th": "เครื่องถ่ายเอกสาร", "en": "Copier"}, "special", {"id": "copier"}],
		[{"th": "ไวท์บอร์ดล้อเลื่อน", "en": "Whiteboard"}, "special", {"id": "wboard"}],
		[{"th": "เคาน์เตอร์ต้อนรับ", "en": "Reception"}, "special", {"id": "reception"}],
		[{"th": "โพเดียม", "en": "Podium"}, "special", {"id": "podium"}],
		[{"th": "เวทียกพื้น", "en": "Stage riser"}, "special", {"id": "riser"}],
		[{"th": "ฟลิปชาร์ต", "en": "Flipchart"}, "special", {"id": "flipchart"}],
		[{"th": "รถเข็น AV", "en": "AV cart"}, "special", {"id": "projcart"}],
		[{"th": "ช่องจดหมาย", "en": "Mail slots"}, "special", {"id": "mailslots"}],
		[{"th": "กล่องปฐมพยาบาล", "en": "First aid"}, "special", {"id": "firstaid", "y": 1.3, "wall": 1}],
		[{"th": "ถังดับเพลิง", "en": "Extinguisher"}, "special", {"id": "fireext"}],
		[{"th": "ป้ายทางออก", "en": "Exit sign"}, "special", {"id": "exitsign", "y": 2.1, "wall": 1}],
		[{"th": "ประตูสแกนบัตร", "en": "Badge gate"}, "special", {"id": "badgegate"}],
		[{"th": "กล้องวงจรปิด", "en": "CCTV"}, "special", {"id": "cctv", "y": 2.2, "wall": 1}],
		[{"th": "กล่องความคิดเห็น", "en": "Suggestion box"}, "special", {"id": "suggest"}],
		[{"th": "เครื่องตอกบัตร", "en": "Time clock"}, "special", {"id": "timeclock", "y": 1.3, "wall": 1}],
		[{"th": "ฉากกั้นบนโต๊ะ", "en": "Desk divider"}, "special", {"id": "deskdivider", "y": 0.74}],
		[{"th": "โทรศัพท์โต๊ะ", "en": "Desk phone"}, "special", {"id": "deskphone", "y": 0.74}],
		[{"th": "กระดานดำกรอบไม้", "en": "Chalkboard"}, "special", {"id": "chalkboard"}],
		[{"th": "บอร์ดหมุดโน้ต", "en": "Pinboard"}, "special", {"id": "corkboard"}],
		[{"th": "ที่ใส่แม็กกาซีน", "en": "Magazine files"}, "special", {"id": "magfiles", "y": 0.74}],
		[{"th": "ชุดจัดโต๊ะ", "en": "Desk organizer"}, "special", {"id": "organizer", "y": 0.74}],
		[{"th": "พาร์ทิชัน", "en": "Partition"}, "special", {"id": "cubpanel", "_pal": 1}],
		[{"th": "โรลอัพ", "en": "Roll-up"}, "special", {"id": "rollup", "_pal": 1}],
		[{"th": "ซับเสียง", "en": "Acoustic"}, "special", {"id": "acoustic", "y": 1.5, "wall": 1, "_pal": 1}],
	]],
	["cat_fun", [
		[{"th": "โต๊ะแอร์ฮอกกี้", "en": "Air hockey"}, "special", {"id": "air_hockey"}],
		[{"th": "กรีนพัตต์กอล์ฟ", "en": "Putting green"}, "special", {"id": "putting_green"}],
		[{"th": "กระสอบทรายตั้งพื้น", "en": "Punching bag"}, "special", {"id": "punching_bag"}],
		[{"th": "อ่างสปาขาสิงห์", "en": "Clawfoot spa tub"}, "special", {"id": "clawfoot_tub"}],
		[{"th": "โต๊ะปิงปอง", "en": "Ping-pong table"}, "special", {"id": "pingpong"}],
		[{"th": "แกรนด์เปียโน", "en": "Grand piano"}, "special", {"id": "piano"}],
		[{"th": "ตู้เพลง", "en": "Jukebox"}, "special", {"id": "jukebox"}],
		[{"th": "ชิงช้า", "en": "Swing set"}, "special", {"id": "swing"}],
		[{"th": "อ่างน้ำร้อน", "en": "Hot tub"}, "special", {"id": "hottub"}],
		[{"th": "ตู้เกมอาร์เคด", "en": "Arcade cabinet"}, "special", {"id": "arcade"}],
		[{"th": "พินบอล", "en": "Pinball"}, "special", {"id": "pinball"}],
		[{"th": "เป้าปาลูกดอก", "en": "Dartboard"}, "special", {"id": "dartboard", "y": 1.55, "wall": 1}],
		[{"th": "โต๊ะโกล์", "en": "Foosball"}, "special", {"id": "foosball"}],
		[{"th": "แป้นบาส", "en": "Basketball hoop"}, "special", {"id": "hoop"}],
		[{"th": "กีตาร์ขาตั้ง", "en": "Guitar"}, "special", {"id": "guitar"}],
		[{"th": "ชุดกลอง", "en": "Drum kit"}, "special", {"id": "drums"}],
		[{"th": "โต๊ะดีเจ", "en": "DJ booth"}, "special", {"id": "djbooth"}],
		[{"th": "เครื่องคาราโอเกะ", "en": "Karaoke"}, "special", {"id": "karaoke"}],
		[{"th": "ตู้คีบตุ๊กตา", "en": "Claw machine"}, "special", {"id": "claw"}],
		[{"th": "กล้องดูดาว", "en": "Telescope"}, "special", {"id": "telescope"}],
		[{"th": "หุ่นยนต์มาสคอต", "en": "Robot mascot"}, "special", {"id": "robot"}],
		[{"th": "ลู่วิ่ง", "en": "Treadmill"}, "special", {"id": "treadmill"}],
		[{"th": "เก้าอี้นวด", "en": "Massage chair"}, "special", {"id": "massagechair"}],
		[{"th": "เครื่องป๊อปคอร์น", "en": "Popcorn machine"}, "special", {"id": "popcorn"}],
		[{"th": "รถเข็นกาแฟ", "en": "Coffee cart"}, "special", {"id": "coffeecart"}],
		[{"th": "ตู้ถ่ายรูป", "en": "Photo booth"}, "special", {"id": "photobooth"}],
		[{"th": "คอนโดแมว", "en": "Cat tree"}, "special", {"id": "cattree"}],
		[{"th": "สกู๊ตเตอร์วินเทจ", "en": "Vintage scooter"}, "special", {"id": "scooter"}],
		[{"th": "สเก็ตบอร์ด", "en": "Skateboard"}, "special", {"id": "skateboard", "_pal": 1}],
		[{"th": "โต๊ะพูล", "en": "Pool table"}, "special", {"id": "pool", "_pal": 1}],
	]],
	["cat_floor", [
		[{"th": "ยางลบพื้น (คืนลายเดิม)", "en": "Eraser (original)"}, "floor", {"erase": 1}],
		[{"th": "ไม้เด็ค", "en": "Wood deck"}, "floor", {"tex": "deck"}],
		[{"th": "คอนกรีต", "en": "Concrete"}, "floor", {"tex": "concrete"}],
		[{"th": "คอนกรีตเข้ม", "en": "Dark concrete"}, "floor", {"tex": "concrete_dark"}],
		[{"th": "พรมฟ้าเทา", "en": "Blue carpet"}, "floor", {"tex": "carpet"}],
		[{"th": "หินขัด", "en": "Terrazzo"}, "floor", {"tex": "atrium"}],
		[{"th": "หญ้า", "en": "Grass"}, "floor", {"tex": "grass"}],
		[{"th": "หินอ่อนขาว", "en": "White marble"}, "floor", {"col": "e8e6e1"}],
		[{"th": "พรมแดงอิฐ", "en": "Clay carpet"}, "floor", {"col": "b3705c"}],
		[{"th": "พรมเขียวเสจ", "en": "Sage carpet"}, "floor", {"col": "8fa287"}],
		[{"th": "ดำด้าน", "en": "Matte black"}, "floor", {"col": "2b2c30"}],
		[{"th": "ครีม", "en": "Cream"}, "floor", {"col": "f3ead8"}],
		[{"th": "เทาอ่อน", "en": "Light gray"}, "floor", {"col": "c9c9c6"}],
		[{"th": "กรมท่า", "en": "Navy"}, "floor", {"col": "2e3a52"}],
		[{"th": "เขียวป่า", "en": "Forest"}, "floor", {"col": "2f4f3e"}],
		[{"th": "มัสตาร์ด", "en": "Mustard"}, "floor", {"col": "c9a13b"}],
		[{"th": "ชมพูพาสเทล", "en": "Pastel pink"}, "floor", {"col": "e8c4c8"}],
		[{"th": "ม่วงพาสเทล", "en": "Pastel purple"}, "floor", {"col": "cbb8d9"}],
		[{"th": "ฟ้าพาสเทล", "en": "Pastel blue"}, "floor", {"col": "b8cfe0"}],
		[{"th": "อิฐแดง", "en": "Brick red"}, "floor", {"col": "9c4a35"}],
		[{"th": "ช็อกโกแลต", "en": "Chocolate"}, "floor", {"col": "4a352a"}],
		[{"th": "ขาวนวล", "en": "Warm white"}, "floor", {"col": "f5f2ea"}],
		[{"th": "หินชนวน", "en": "Slate"}, "floor", {"col": "3a3d42"}],
		[{"th": "เทียล", "en": "Teal"}, "floor", {"col": "2a7f86"}],
		[{"th": "แซลมอน", "en": "Salmon"}, "floor", {"col": "e89a7d"}],
		[{"th": "ไลม์", "en": "Lime"}, "floor", {"col": "b5c96a"}],
		[{"th": "เทาเข้ม", "en": "Dark gray"}, "floor", {"col": "6b6d70"}],
		[{"th": "ทราย", "en": "Sand"}, "floor", {"col": "d9c49a"}],
		[{"th": "มินต์", "en": "Mint"}, "floor", {"col": "b8d9c8"}],
		[{"th": "ลาเวนเดอร์", "en": "Lavender"}, "floor", {"col": "b9aed6"}],
		[{"th": "โกโก้", "en": "Cocoa"}, "floor", {"col": "6e5442"}],
	]],
	["cat_wall", [
		[{"th": "ฉากกั้นตะแกรง", "en": "Grid divider"}, "special", {"id": "griddiv"}],
		[{"th": "กระจกกั้น 2 ม.", "en": "Glass 2m"}, "wall", {"w": 2.0, "glass": 1}],
		[{"th": "กระจกกั้น 1 ม.", "en": "Glass 1m"}, "wall", {"w": 1.0, "glass": 1}],
		[{"th": "กระจกกรอบดำ 2 ม.", "en": "Framed glass 2m"}, "special", {"id": "glassframe", "w": 2.0}],
		[{"th": "กระจกกรอบดำ 1 ม.", "en": "Framed glass 1m"}, "special", {"id": "glassframe", "w": 1.0}],
		[{"th": "กระจกออฟฟิศ 1 ม.", "en": "Office glass 1m"}, "special", {"id": "gwall", "w": 1.0}],
		[{"th": "กระจกออฟฟิศ 2 ม.", "en": "Office glass 2m"}, "special", {"id": "gwall", "w": 2.0}],
		[{"th": "กระจกออฟฟิศ 3 ม.", "en": "Office glass 3m"}, "special", {"id": "gwall", "w": 3.0}],
		[{"th": "ระแนง", "en": "Slat wall"}, "special", {"id": "slatwall", "_pal": 1}],
		[{"th": "รั้วเตี้ย", "en": "Fence"}, "special", {"id": "fence", "_pal": 1}],
		[{"th": "เสากลม", "en": "Column"}, "special", {"id": "column_p", "_pal": 1}],
		[{"th": "ผนังทึบ", "en": "Wall"}, "wall", {"w": 2.0, "_pal": 1}],
		[{"th": "ครึ่งผนัง", "en": "Half wall"}, "wall", {"w": 2.0, "half": 1, "_pal": 1}],
	]],
]

const PALETTE := [["เทา", "8c8a87"], ["ครีม", "d9cbb0"], ["ดำ", "2b2c30"],
	["ขาว", "f0ede6"], ["เขียวเสจ", "9eab91"], ["เขียวป่า", "2f4f3e"],
	["กรมท่า", "33415e"], ["ฟ้า", "7da7c9"], ["เทียล", "2a7f86"],
	["มัสตาร์ด", "cfa63f"], ["ส้มอิฐ", "c17a5f"], ["ชมพู", "e0b4b8"]]
var _cats: Array = []


## Expand _pal families into one entry per palette colour — every
## family ships in all 12 shades without hand-writing 500 lines.
func _expand_catalog() -> void:
	_cats = []
	for cat in CATALOG:
		var items: Array = []
		for it in cat[1]:
			var params: Dictionary = it[2]
			if int(params.get("_pal", 0)) == 1:
				var np: Dictionary = params.duplicate()
				np.erase("_pal")
				np["_col_ok"] = 1   # one card; colour comes from the swatches
				items.append([it[0], it[1], np])
			else:
				items.append(it)
		_cats.append([cat[0], items])


var cam: Camera3D
var office: Node3D
var active := false
var carrying: Node3D = null
var _carry_new := false          # spawned from catalog, not placed yet
var _carry_entry := {}           # pending catalog entry {kind, params}
var _paint := {}                 # active floor style ({} = off)
var _carry_wall := false         # carried piece is wall-mounted
var _carry_snap := ""            # "", "edge" (walls) or "corner" (columns)
var _last_paint_cell := Vector2i(-9999, -9999)
# The Sims drawing gestures: walls are DRAWN (press a corner, drag along
# an axis, release = one run), floors FILL a dragged rectangle.
var _wall_draw := {}             # active wall style: {kind, params}
var _draw_from := Vector3.INF
var _draw_preview: Node3D = null
var _draw_len := 0.0
var _draw_horiz := true
var _rect_from := Vector2i(-9999, -9999)
var _rect_hl: MeshInstance3D = null
var _swatch_row: HBoxContainer
# PRE-LOCATE (The Sims footprint): a translucent tile-strip that always
# shows exactly where the carried piece / wall run will land.
var _foot: MeshInstance3D = null
var _foot_size := Vector2.ZERO
var _hov_h := true               # last hover orientation for 1-click walls
var _wall_ok := false            # currently snapped to a wall
var _orig: Transform3D
var _ring: MeshInstance3D
var _ui: CanvasLayer
var _grid: GridContainer
var _cat_bar: HFlowContainer
var _cur_cat := 0
var _added_seq := 0
var _icon_cache := {}            # kind+params -> Texture2D (rendered once)
var _icon_gen := 0               # cancels stale async icon fills
var _vp: SubViewport
var _vp_cam: Camera3D
var _vp_root: Node3D

signal mode_changed(on: bool)


func _ready() -> void:
	_expand_catalog()
	_build_catalog_ui()


func devtest_walls() -> void:
	var before := get_tree().get_nodes_in_group("furniture").size()
	_catalog_pick("wall", {"w": 2.0, "glass": 1})
	_draw_from = Vector3(9, 0, 17)
	_update_draw_preview(3.0, true, 1.0)
	_finish_draw()
	_catalog_pick("special", {"id": "gwall", "w": 2.0})
	_draw_from = Vector3(9, 0, 18)
	_update_draw_preview(2.0, true, 1.0)
	_finish_draw()
	var after := get_tree().get_nodes_in_group("furniture").size()
	print("[walltest] pieces before=%d after=%d (+%d expected 2) added_records=%d" % [
		before, after, after - before, (_load_layout().get("added", []) as Array).size()])
	# leave no trace: free the two test pieces and their records
	var layout := _load_layout()
	var added: Array = layout.get("added", [])
	for _i in 2:
		if added.is_empty():
			break
		var rec: Dictionary = added.pop_back()
		for f in get_tree().get_nodes_in_group("furniture"):
			if str((f as Node).get_meta("piece_id", "")) == str(rec.get("id", "")):
				(f as Node).queue_free()
	layout["added"] = added
	_write_layout(layout)


func toggle() -> void:
	if active and carrying:
		cancel_carry()
	_paint = {}
	_wall_draw = {}
	_cancel_draw()
	_end_rect(false)
	_foot_hide()
	active = not active
	if _ui:
		_ui.visible = active
	if active:
		_show_cat(_cur_cat)   # regenerate icons (office exists by now)
	mode_changed.emit(active)


## Returns true when the click was consumed by build mode.
func handle_click(mpos: Vector2) -> bool:
	if not active or cam == null:
		return false
	if carrying:
		_place()
		return true
	var p := _floor_point(mpos)
	if not _wall_draw.is_empty():
		_draw_from = Vector3(roundf(p.x), 0, roundf(p.z))
		_foot_hide()
		return true
	if not _paint.is_empty():
		var c := office.CELL as float
		_rect_from = Vector2i(int(floorf(p.x / c)), int(floorf(p.z / c)))
		return true
	var best: Node3D = null
	var bd := 0.9
	for f in get_tree().get_nodes_in_group("furniture"):
		if not is_instance_valid(f):
			continue
		var n3 := f as Node3D
		var d: float
		if n3.has_meta("half_len"):
			# long pieces (walls, glass runs, slat screens): distance to
			# the SEGMENT, so clicking anywhere along the run picks it
			var lp: Vector3 = n3.global_transform.affine_inverse() * p
			var dx := maxf(absf(lp.x) - float(n3.get_meta("half_len")), 0.0)
			d = Vector2(dx, lp.z).length()
		else:
			var fp := n3.global_position
			d = Vector2(fp.x - p.x, fp.z - p.z).length()
		if d < bd:
			bd = d
			best = n3
	if best:
		_pick(best)
	return true


func handle_key(keycode: int) -> bool:
	if not active:
		return false
	if keycode == KEY_ESCAPE and not _wall_draw.is_empty():
		_cancel_draw()
		_wall_draw = {}
		_foot_hide()
		return true
	if keycode == KEY_ESCAPE and not _paint.is_empty():
		_paint = {}
		_end_rect(false)
		return true
	if carrying == null:
		return false
	if keycode == KEY_R:
		carrying.rotation_degrees.y = fposmod(carrying.rotation_degrees.y + 90.0, 360.0)
		return true
	if keycode == KEY_X or keycode == KEY_DELETE or keycode == KEY_BACKSPACE:
		_delete_carried()
		return true
	if keycode == KEY_ESCAPE:
		cancel_carry()
		return true
	return false


func _process(_delta: float) -> void:
	if not active or cam == null:
		return
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# WALL DRAWING (The Sims): press a corner, drag along an axis — live
	# preview grows in whole tiles; release builds the run as one piece
	if not _wall_draw.is_empty() and _draw_from == Vector3.INF and carrying == null:
		# hover pre-locate: show the edge-snapped start tile before the press
		var hp := _floor_point(get_viewport().get_mouse_position())
		var fx2 := absf(hp.x - roundf(hp.x))
		var fz2 := absf(hp.z - roundf(hp.z))
		_hov_h = fz2 <= fx2
		var hpos := Vector3(snappedf(hp.x, 0.5), 0, roundf(hp.z)) if _hov_h \
			else Vector3(roundf(hp.x), 0, snappedf(hp.z, 0.5))
		_foot_show(hpos, Vector2(1.08, 0.22), 0.0 if _hov_h else 90.0)
	if not _wall_draw.is_empty() and _draw_from != Vector3.INF:
		var fp := _floor_point(get_viewport().get_mouse_position())
		var ex := roundf(fp.x)
		var ez := roundf(fp.z)
		var dx := ex - _draw_from.x
		var dz := ez - _draw_from.z
		var horiz := absf(dx) >= absf(dz)
		var ln := clampf(absf(dx) if horiz else absf(dz), 1.0, 14.0)
		if lmb:
			if ln != _draw_len or horiz != _draw_horiz:
				_update_draw_preview(ln, horiz, signf(dx if horiz else dz))
			if _draw_preview:
				_foot_show(_draw_preview.position, Vector2(ln + 0.12, 0.26),
					_draw_preview.rotation_degrees.y)
			return
		_finish_draw()
		_foot_hide()
		return
	# FLOOR RECT FILL: drag a rectangle, release pours the style
	if not _paint.is_empty() and _rect_from.x > -9000:
		if lmb:
			_update_rect_highlight()
			return
		_end_rect(true)
		return
	if carrying == null:
		return
	var p := _floor_point(get_viewport().get_mouse_position())
	if not _carry_snap.is_empty():
		var yrot := fposmod(carrying.rotation_degrees.y, 180.0)
		var horiz := yrot < 45.0 or yrot > 135.0
		if _carry_snap == "corner":
			carrying.position.x = roundf(p.x)
			carrying.position.z = roundf(p.z)
		elif horiz:
			carrying.position.x = snappedf(p.x, 0.5)
			carrying.position.z = roundf(p.z)
		else:
			carrying.position.x = roundf(p.x)
			carrying.position.z = snappedf(p.z, 0.5)
		return
	if _carry_wall:
		# The Sims rule: wall-mounted pieces live ON walls only — glue
		# to the nearest wall face and turn to face the room.
		var sn := _wall_snap(p)
		_wall_ok = not sn.is_empty()
		if _wall_ok:
			carrying.position.x = sn.pos.x
			carrying.position.z = sn.pos.z
			carrying.rotation_degrees.y = sn.rot
			_foot_show(carrying.position, _foot_size, carrying.rotation_degrees.y)
			return
	carrying.position.x = snappedf(p.x, SNAP)
	carrying.position.z = snappedf(p.z, SNAP)
	_foot_show(carrying.position, _foot_size, carrying.rotation_degrees.y,
		_carry_wall and not _wall_ok)


## Nearest wall face within reach of the cursor: office walls, window
## glass runs and owner-placed partitions all count as surfaces.
func _wall_snap(p: Vector3) -> Dictionary:
	var best := {}
	var bd := 1.3
	for wn in get_tree().get_nodes_in_group("wall_surface"):
		var n3 := wn as Node3D
		if n3 == null or not is_instance_valid(n3):
			continue
		if carrying and (n3 == carrying or carrying.is_ancestor_of(n3)):
			continue
		var along: Vector3
		var nrm: Vector3
		if n3.has_meta("horiz"):
			along = Vector3(1, 0, 0) if bool(n3.get_meta("horiz")) else Vector3(0, 0, 1)
			nrm = Vector3(0, 0, 1) if bool(n3.get_meta("horiz")) else Vector3(1, 0, 0)
		else:
			along = n3.global_transform.basis.x.normalized()
			nrm = n3.global_transform.basis.z.normalized()
		var wp := n3.global_position
		var d := p - wp
		var u := d.dot(along)
		var v := d.dot(nrm)
		var hl := float(n3.get_meta("half_len", 0.5))
		if absf(u) > hl or absf(v) > bd:
			continue
		bd = absf(v)
		var side := 1.0 if v >= 0.0 else -1.0
		var out := nrm * side
		best = {
			"pos": Vector3(wp.x, 0, wp.z) + along * u
				+ out * (float(n3.get_meta("half_t", 0.08)) + 0.02),
			"rot": rad_to_deg(atan2(out.x, out.z)),
		}
	return best


## Repaint the carried piece: respawn its recipe with the new colour at
## the same spot/rotation; existing purchases keep their id + saved
## record, fresh spawns stay fresh. Built-ins without a recipe skip.
func _recolor(hex: String) -> void:
	if carrying == null or office == null:
		return
	var entry := _carry_entry
	var keep_id := ""
	if entry.is_empty():
		var id := str(carrying.get_meta("piece_id", ""))
		if not id.begins_with("a"):
			return
		for e in _load_layout().get("added", []):
			if str(e.get("id", "")) == id:
				entry = {"kind": str(e.get("kind", "")), "params": e.get("params", {})}
				keep_id = id
		if entry.is_empty():
			return
	elif not _carry_new:
		keep_id = str(carrying.get_meta("piece_id", ""))
	var params: Dictionary = (entry.get("params", {}) as Dictionary).duplicate()
	if not (params.has("col") or params.has("_col_ok")):
		return
	params["col"] = hex
	var pos := carrying.position
	var rot := carrying.rotation_degrees.y
	var was_new := _carry_new
	var was_wall := _carry_wall
	_drop_ring()
	carrying.queue_free()
	var node := _spawn(str(entry.get("kind", "")), params, Vector3(pos.x, 0, pos.z))
	if node == null:
		carrying = null
		return
	node.position = pos
	node.rotation_degrees.y = rot
	carrying = node
	_carry_new = was_new
	_carry_wall = was_wall
	_carry_entry = {"kind": entry.get("kind", ""), "params": params}
	if was_wall:
		node.set_meta("wall_item", true)
	if not keep_id.is_empty():
		node.set_meta("piece_id", keep_id)
		var layout := _load_layout()
		for e in layout.get("added", []):
			if str(e.get("id", "")) == keep_id:
				e["params"] = params
		_write_layout(layout)
		_carry_new = false
	_attach_ring()
	Sfx.play_ui("paper", -12.0)


func _colorable() -> bool:
	if carrying == null:
		return false
	if not _carry_entry.is_empty():
		var pr: Dictionary = _carry_entry.get("params", {})
		return pr.has("col") or pr.has("_col_ok")
	var id := str(carrying.get_meta("piece_id", ""))
	if not id.begins_with("a"):
		return false
	for e in _load_layout().get("added", []):
		if str(e.get("id", "")) == id:
			var pr2: Dictionary = e.get("params", {})
			return pr2.has("col") or pr2.has("_col_ok")
	return false


func _update_swatches() -> void:
	if _swatch_row:
		_swatch_row.visible = _colorable()


# ---------------------------------------------------------------- carry

func _pick(piece: Node3D) -> void:
	carrying = piece
	_carry_new = false
	_carry_entry = {}
	_carry_wall = bool(piece.get_meta("wall_item", false))
	_carry_snap = str(piece.get_meta("snap_mode", ""))
	_wall_ok = not _carry_wall
	_orig = piece.transform
	var ab: AABB = office._combined_aabb(piece, Transform3D.IDENTITY)
	_foot_size = Vector2(maxf(ab.size.x, 0.3) + 0.12, maxf(ab.size.z, 0.3) + 0.12)
	Sfx.play_ui("paper", -10.0)
	_attach_ring()
	_update_swatches()


func _place() -> void:
	if _carry_wall and not _wall_ok:
		Sfx.play_ui("error", -10.0)   # Sims rule: needs a wall
		return
	if _carry_new:
		_record_added(carrying, _carry_entry)
	else:
		_save_move(carrying)
	_drop_ring()
	Sfx.play_ui("chair", -8.0)
	carrying = null
	_carry_new = false
	_carry_entry = {}
	_carry_snap = ""
	_foot_hide()
	_update_swatches()


func cancel_carry() -> void:
	if carrying == null:
		return
	if _carry_new:
		carrying.queue_free()      # never placed — vanish, nothing saved
	else:
		carrying.transform = _orig
	_drop_ring()
	carrying = null
	_carry_new = false
	_carry_entry = {}
	_carry_snap = ""
	_foot_hide()
	_update_swatches()


func _delete_carried() -> void:
	var id := str(carrying.get_meta("piece_id", ""))
	var layout := _load_layout()
	if _carry_new:
		pass                        # not saved yet — just free it
	elif id.begins_with("a"):       # owner-added earlier: drop its record
		var added: Array = layout.get("added", [])
		for i in range(added.size() - 1, -1, -1):
			if str(added[i].get("id", "")) == id:
				added.remove_at(i)
		layout["added"] = added
		_write_layout(layout)
	else:                           # built-in: remember it's gone
		var del: Array = layout.get("deleted", [])
		if not del.has(id):
			del.append(id)
		layout["deleted"] = del
		layout.get("moved", {}).erase(id)
		_write_layout(layout)
	carrying.queue_free()
	_prune_posts(_load_layout())
	_drop_ring()
	Sfx.play_ui("paper", -12.0)
	carrying = null
	_carry_new = false
	_carry_entry = {}
	_carry_snap = ""
	_foot_hide()
	_update_swatches()


func _attach_ring() -> void:
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.34
	t.outer_radius = 0.42
	_ring.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.78, 0.32, 0.85)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = m
	_ring.position = Vector3(0, 0.05, 0)
	carrying.add_child(_ring)


func _drop_ring() -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _floor_point(mpos: Vector2) -> Vector3:
	var from := cam.project_ray_origin(mpos)
	var dir := cam.project_ray_normal(mpos)
	if absf(dir.y) < 0.0001:
		return from
	var t := -from.y / dir.y
	return from + dir * t


func _ensure_foot() -> MeshInstance3D:
	if _foot == null or not is_instance_valid(_foot):
		_foot = MeshInstance3D.new()
		_foot.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.78, 0.32, 0.35)
		_foot.material_override = m
		office.add_child(_foot)
	return _foot


func _foot_show(pos: Vector3, size: Vector2, yrot: float, bad: bool = false) -> void:
	var ft := _ensure_foot()
	(ft.mesh as BoxMesh).size = Vector3(size.x, 0.015, size.y)
	ft.position = Vector3(pos.x, 0.025, pos.z)
	ft.rotation_degrees = Vector3(0, yrot, 0)
	(ft.material_override as StandardMaterial3D).albedo_color = \
		Color(0.95, 0.35, 0.30, 0.42) if bad else Color(1.0, 0.78, 0.32, 0.35)


func _foot_hide() -> void:
	if _foot and is_instance_valid(_foot):
		_foot.queue_free()
	_foot = null


# ------------------------------------------------ drawing gestures

func _update_draw_preview(ln: float, horiz: bool, dir: float) -> void:
	_cancel_draw()
	_draw_len = ln
	_draw_horiz = horiz
	var half := ln / 2.0 * (1.0 if dir >= 0 else -1.0)
	var mid := _draw_from + (Vector3(half, 0, 0) if horiz else Vector3(0, 0, half))
	var params: Dictionary = (_wall_draw["params"] as Dictionary).duplicate()
	params["w"] = ln
	_draw_preview = _spawn(str(_wall_draw["kind"]), params, mid)
	if _draw_preview:
		_draw_preview.rotation_degrees.y = 0.0 if horiz else 90.0


func _finish_draw() -> void:
	if _draw_preview == null and _draw_from != Vector3.INF:
		# click without drag: place one segment, oriented like the hover
		_update_draw_preview(1.0, _hov_h, 1.0)
	if _draw_preview:
		var params: Dictionary = (_wall_draw["params"] as Dictionary).duplicate()
		params["w"] = _draw_len
		if int(params.get("wall", 0)) == 0:
			pass
		_record_added(_draw_preview, {"kind": str(_wall_draw["kind"]), "params": params})
		Sfx.play_ui("chair", -8.0)
		_draw_preview = null
	_draw_from = Vector3.INF
	_draw_len = 0.0


func _cancel_draw() -> void:
	if _draw_preview and is_instance_valid(_draw_preview):
		_draw_preview.queue_free()
	_draw_preview = null
	_draw_from = Vector3.INF
	_draw_len = 0.0


func _update_rect_highlight() -> void:
	var fp := _floor_point(get_viewport().get_mouse_position())
	var c := office.CELL as float
	var cell := Vector2i(int(floorf(fp.x / c)), int(floorf(fp.z / c)))
	var a := Vector2i(mini(_rect_from.x, cell.x), mini(_rect_from.y, cell.y))
	var bb := Vector2i(maxi(_rect_from.x, cell.x), maxi(_rect_from.y, cell.y))
	if _rect_hl == null or not is_instance_valid(_rect_hl):
		_rect_hl = MeshInstance3D.new()
		_rect_hl.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.28)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rect_hl.material_override = m
		office.add_child(_rect_hl)
	(_rect_hl.mesh as BoxMesh).size = Vector3((bb.x - a.x + 1) * c, 0.02, (bb.y - a.y + 1) * c)
	_rect_hl.position = Vector3((a.x + bb.x + 1) * c / 2.0, 0.04, (a.y + bb.y + 1) * c / 2.0)


func _end_rect(apply: bool) -> void:
	if apply and _rect_from.x > -9000:
		var fp := _floor_point(get_viewport().get_mouse_position())
		var c := office.CELL as float
		var cell := Vector2i(int(floorf(fp.x / c)), int(floorf(fp.z / c)))
		var a := Vector2i(mini(_rect_from.x, cell.x), mini(_rect_from.y, cell.y))
		var bb := Vector2i(maxi(_rect_from.x, cell.x), maxi(_rect_from.y, cell.y))
		var layout := _load_layout()
		var floors: Dictionary = layout.get("floors", {})
		var erase := int(_paint.get("erase", 0)) == 1
		for gy in range(a.y, bb.y + 1):
			for gx in range(a.x, bb.x + 1):
				var cl := Vector2i(gx, gy)
				if not office.floor_tiles.has(cl):
					continue
				var mi := office.floor_tiles[cl] as MeshInstance3D
				if erase:
					mi.material_override = null
					floors.erase("%d,%d" % [cl.x, cl.y])
				else:
					mi.material_override = _floor_mat(_paint)
					floors["%d,%d" % [cl.x, cl.y]] = _paint
		layout["floors"] = floors
		_write_layout(layout)
		Sfx.play_ui("paper", -12.0)
	_rect_from = Vector2i(-9999, -9999)
	if _rect_hl and is_instance_valid(_rect_hl):
		_rect_hl.queue_free()
	_rect_hl = null


# ----------------------------------------------------------- floor paint

func _paint_tile(p: Vector3) -> void:
	var cell := Vector2i(int(floorf(p.x / office.CELL)), int(floorf(p.z / office.CELL)))
	if not office.floor_tiles.has(cell):
		return
	var mi := office.floor_tiles[cell] as MeshInstance3D
	var layout := _load_layout()
	var floors: Dictionary = layout.get("floors", {})
	if int(_paint.get("erase", 0)) == 1:
		# eraser: back to the room's ORIGINAL material (the mesh's own)
		mi.material_override = null
		floors.erase("%d,%d" % [cell.x, cell.y])
	else:
		mi.material_override = _floor_mat(_paint)
		floors["%d,%d" % [cell.x, cell.y]] = _paint
	Sfx.play_ui("paper", -14.0)
	layout["floors"] = floors
	_write_layout(layout)


func _floor_mat(style: Dictionary) -> StandardMaterial3D:
	if int(style.get("erase", 0)) == 1:   # icon swatch for the eraser
		return office._mat("bfloor_eraser", Color(0.93, 0.72, 0.70))
	if style.has("tex"):
		return office._mat("floor_" + str(style["tex"]), Color.WHITE,
			"res://assets/textures/%s.png" % str(style["tex"]))
	return office._mat("bfloor_" + str(style.get("col", "ffffff")),
		Color.html(str(style.get("col", "ffffff"))))


# ------------------------------------------------------------- catalog

func _spawn(kind: String, params: Dictionary, at: Vector3) -> Node3D:
	if office == null:
		return null
	match kind:
		"chair":
			return office._task_chair(at.x, at.z, 180.0)
		"sofa":
			return office._modern_sofa(at.x, at.z, 0.0,
				Color.html(str(params.get("col", "8c8a87"))))
		"armchair":
			return office._modern_armchair(at.x, at.z, 0.0,
				Color.html(str(params.get("col", "4d619e"))))
		"shelf":
			return office._shelving(at.x, at.z, 0.0)
		"prop":
			return office._prop(str(params.get("model", "")), at.x, at.z, 0.0,
				float(params.get("fit", 1.0)), float(params.get("y", 0.0)),
				float(params.get("fit_h", 0.0)))
		"glb":
			return _spawn_glb(params, at)
		"wall":
			return _spawn_wall(params, at)
		"special":
			return _spawn_special(str(params.get("id", "")), params, at)
	return null


# ------------------------------- Sims-inspired originals (procedural)

func _cyl(rt: float, rb: float, h: float, pos: Vector3, m: Material,
		parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sph(r: float, pos: Vector3, m: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _emat(col: Color, energy := 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _glass_mat(col := Color(0.72, 0.84, 0.90, 0.26)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.05
	return m


func _omni(pos: Vector3, col: Color, energy: float, rng: float, parent: Node3D) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	parent.add_child(l)


func _spawn_special(id: String, params: Dictionary, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(at.x, float(params.get("y", 0.0)), at.z)
	office.add_child(root)
	office._movable(root)
	var wood: StandardMaterial3D = office._mat("sp_wood", Color(0.55, 0.42, 0.30))
	var dwood: StandardMaterial3D = office._mat("sp_dwood", Color(0.33, 0.25, 0.19))
	var metal: StandardMaterial3D = office._mat("sp_metal", Color(0.46, 0.47, 0.50))
	var white: StandardMaterial3D = office._mat("sp_white", Color(0.94, 0.93, 0.90))
	var black: StandardMaterial3D = office._mat("sp_black", Color(0.10, 0.10, 0.12))
	var pchex := str(params.get("col", "cccccc"))
	match id:
		"bed":
			office._box(Vector3(1.65, 0.25, 2.10), Vector3(0, 0.25, 0), dwood, root, false)
			office._box(Vector3(1.65, 0.72, 0.08), Vector3(0, 0.60, -1.01), dwood, root, false)
			office._box(Vector3(1.55, 0.16, 1.95), Vector3(0, 0.455, 0.02), white, root, false)
			office._box(Vector3(1.57, 0.07, 1.15), Vector3(0, 0.57, 0.42),
				office._mat("sp_blanket", Color(0.42, 0.52, 0.65)), root, false)
			for px in [-0.40, 0.40]:
				office._box(Vector3(0.55, 0.11, 0.35), Vector3(px, 0.585, -0.70), white, root, false)
		"piano":
			for leg in [Vector3(-0.60, 0.35, 0.35), Vector3(0.60, 0.35, 0.35), Vector3(0, 0.35, -0.40)]:
				_cyl(0.045, 0.045, 0.70, leg, black, root)
			office._box(Vector3(1.40, 0.30, 0.95), Vector3(0, 0.85, 0), black, root, false)
			office._box(Vector3(0.90, 0.06, 0.24), Vector3(0, 0.82, 0.58), white, root, false)
			office._box(Vector3(0.90, 0.02, 0.10), Vector3(0, 0.86, 0.52), black, root, false)
			var lid: MeshInstance3D = office._box(Vector3(1.30, 0.03, 0.85), Vector3(0, 1.12, -0.12), black, root, false)
			lid.rotation_degrees = Vector3(-18, 0, 0)
			office._box(Vector3(0.50, 0.06, 0.30), Vector3(0, 0.45, 0.95), dwood, root, false)
			for bl in [Vector3(-0.2, 0.21, 0.95), Vector3(0.2, 0.21, 0.95)]:
				office._box(Vector3(0.05, 0.42, 0.26), bl, dwood, root, false)
		"fireplace":
			var stone: StandardMaterial3D = office._mat("sp_stone", Color(0.58, 0.56, 0.53))
			office._box(Vector3(1.40, 0.15, 0.50), Vector3(0, 0.075, 0), stone, root, false)
			for sx in [-0.575, 0.575]:
				office._box(Vector3(0.25, 1.05, 0.45), Vector3(sx, 0.675, 0), stone, root, false)
			office._box(Vector3(1.40, 0.22, 0.45), Vector3(0, 1.31, 0), stone, root, false)
			office._box(Vector3(1.52, 0.06, 0.52), Vector3(0, 1.45, 0), dwood, root, false)
			office._box(Vector3(0.90, 1.0, 0.06), Vector3(0, 0.65, -0.19), black, root, false)
			for lg in [Vector3(-0.1, 0.22, 0.02), Vector3(0.12, 0.20, -0.06)]:
				_cyl(0.05, 0.05, 0.5, lg, dwood, root, Vector3(0, 0, 90))
			_sph(0.13, Vector3(-0.08, 0.32, -0.02), _emat(Color(1.0, 0.45, 0.10), 2.2), root)
			_sph(0.10, Vector3(0.10, 0.30, 0.0), _emat(Color(1.0, 0.62, 0.15), 2.2), root)
			_sph(0.07, Vector3(0.0, 0.42, -0.02), _emat(Color(1.0, 0.80, 0.30), 2.4), root)
			_omni(Vector3(0, 0.55, 0.3), Color(1.0, 0.60, 0.25), 1.3, 3.2, root)
		"aquarium":
			office._box(Vector3(0.95, 0.55, 0.50), Vector3(0, 0.275, 0), dwood, root, false)
			office._box(Vector3(0.90, 0.50, 0.42), Vector3(0, 0.80, 0), _glass_mat(), root, false)
			office._box(Vector3(0.86, 0.42, 0.38), Vector3(0, 0.78, 0),
				_glass_mat(Color(0.25, 0.55, 0.75, 0.45)), root, false)
			office._box(Vector3(0.86, 0.05, 0.38), Vector3(0, 0.585, 0),
				office._mat("sp_gravel", Color(0.72, 0.66, 0.55)), root, false)
			var fish := [[Color(1.0, 0.55, 0.15), Vector3(-0.2, 0.75, 0.05)],
				[Color(0.25, 0.75, 0.80), Vector3(0.15, 0.88, -0.05)],
				[Color(0.95, 0.80, 0.25), Vector3(0.05, 0.68, 0.08)]]
			for f in fish:
				var fm := _emat(f[0], 0.6)
				var fb: MeshInstance3D = office._box(Vector3(0.09, 0.045, 0.02), f[1], fm, root, false)
				fb.rotation_degrees = Vector3(0, randf_range(-40, 40), 0)
			office._box(Vector3(0.94, 0.06, 0.46), Vector3(0, 1.08, 0), black, root, false)
			_omni(Vector3(0, 0.95, 0), Color(0.55, 0.85, 1.0), 0.7, 1.6, root)
		"lava":
			_cyl(0.05, 0.095, 0.13, Vector3(0, 0.065, 0), metal, root)
			_cyl(0.048, 0.078, 0.30, Vector3(0, 0.28, 0),
				_glass_mat(Color(0.55, 0.25, 0.65, 0.40)), root)
			_sph(0.038, Vector3(0.008, 0.20, 0), _emat(Color(1.0, 0.25, 0.55), 2.4), root)
			_sph(0.028, Vector3(-0.01, 0.33, 0), _emat(Color(1.0, 0.35, 0.45), 2.4), root)
			_sph(0.018, Vector3(0.012, 0.40, 0), _emat(Color(1.0, 0.45, 0.40), 2.2), root)
			_cyl(0.03, 0.05, 0.07, Vector3(0, 0.465, 0), metal, root)
			_omni(Vector3(0, 0.30, 0), Color(1.0, 0.35, 0.55), 0.65, 1.4, root)
		"crt":
			for lx in [-0.24, 0.24]:
				for lz in [-0.16, 0.16]:
					_cyl(0.018, 0.025, 0.25, Vector3(lx, 0.125, lz), dwood, root)
			office._box(Vector3(0.62, 0.50, 0.45), Vector3(0, 0.50, 0), wood, root, false)
			office._box(Vector3(0.44, 0.34, 0.03), Vector3(-0.05, 0.52, 0.225),
				_emat(Color(0.35, 0.85, 0.80), 1.1), root, false)
			for dy in [0.62, 0.50, 0.38]:
				_cyl(0.028, 0.028, 0.03, Vector3(0.24, dy, 0.225), black, root, Vector3(90, 0, 0))
		"pool":
			for lx in [-0.95, 0.95]:
				for lz in [-0.45, 0.45]:
					office._box(Vector3(0.13, 0.76, 0.13), Vector3(lx, 0.38, lz), dwood, root, false)
			office._box(Vector3(2.20, 0.20, 1.20), Vector3(0, 0.80, 0), dwood, root, false)
			var felt: StandardMaterial3D = office._mat("sp_feltc_" + pchex, Color.html(pchex)) if params.has("col") else office._mat("sp_felt", Color(0.15, 0.45, 0.28))
			office._box(Vector3(2.02, 0.03, 1.02), Vector3(0, 0.915, 0), felt, root, false)
			for rz in [-0.56, 0.56]:
				office._box(Vector3(2.20, 0.07, 0.09), Vector3(0, 0.945, rz), wood, root, false)
			for rx in [-1.06, 1.06]:
				office._box(Vector3(0.09, 0.07, 1.20), Vector3(rx, 0.945, 0), wood, root, false)
			for pk in [Vector3(-1.02, 0.93, -0.52), Vector3(1.02, 0.93, -0.52), Vector3(-1.02, 0.93, 0.52),
					Vector3(1.02, 0.93, 0.52), Vector3(0, 0.93, -0.56), Vector3(0, 0.93, 0.56)]:
				_cyl(0.055, 0.055, 0.04, pk, black, root)
			var ball_cols := [Color(0.9, 0.2, 0.2), Color(0.95, 0.75, 0.2), Color(0.25, 0.35, 0.8),
				Color(0.2, 0.55, 0.3), Color(0.55, 0.25, 0.6)]
			for i in ball_cols.size():
				_sph(0.030, Vector3(0.25 + (i % 3) * 0.07, 0.955, -0.10 + (i / 3) * 0.07),
					office._mat("sp_ball%d" % i, ball_cols[i]), root)
			_sph(0.030, Vector3(-0.55, 0.955, 0.12), white, root)
			var cue: MeshInstance3D = office._box(Vector3(1.40, 0.022, 0.022), Vector3(-0.2, 0.96, 0.30), wood, root, false)
			cue.rotation_degrees = Vector3(0, 14, 0)
		"jukebox":
			var body: StandardMaterial3D = office._mat("sp_juke", Color(0.48, 0.16, 0.14))
			office._box(Vector3(0.85, 1.35, 0.55), Vector3(0, 0.675, 0), body, root, false)
			_cyl(0.425, 0.425, 0.55, Vector3(0, 1.35, 0), body, root, Vector3(90, 0, 0))
			office._box(Vector3(0.52, 0.30, 0.03), Vector3(0, 1.32, 0.27),
				_emat(Color(1.0, 0.75, 0.35), 1.3), root, false)
			office._box(Vector3(0.55, 0.50, 0.03), Vector3(0, 0.55, 0.27), black, root, false)
			for nx in [-0.37, 0.37]:
				office._box(Vector3(0.06, 1.05, 0.03), Vector3(nx, 0.70, 0.27),
					_emat(Color(1.0, 0.30, 0.65), 1.6), root, false)
			_omni(Vector3(0, 1.1, 0.5), Color(1.0, 0.45, 0.70), 0.8, 2.2, root)
		"swing":
			for sx in [-1.15, 1.15]:
				_cyl(0.04, 0.04, 2.35, Vector3(sx - 0.25, 1.08, 0), metal, root, Vector3(0, 0, 13))
				_cyl(0.04, 0.04, 2.35, Vector3(sx + 0.25, 1.08, 0), metal, root, Vector3(0, 0, -13))
			_cyl(0.045, 0.045, 2.45, Vector3(0, 2.16, 0), metal, root, Vector3(0, 0, 90))
			for swx in [-0.50, 0.50]:
				for rp in [-0.18, 0.18]:
					office._box(Vector3(0.02, 0.86, 0.02), Vector3(swx + rp, 1.70, 0), metal, root, false)
				office._box(Vector3(0.46, 0.04, 0.20), Vector3(swx, 1.26, 0), wood, root, false)
		"hottub":
			_cyl(0.95, 0.95, 0.72, Vector3(0, 0.36, 0),
				office._mat("sp_tubwood", Color(0.50, 0.36, 0.26)), root)
			_cyl(0.97, 0.97, 0.07, Vector3(0, 0.735, 0), dwood, root)
			_cyl(0.82, 0.82, 0.05, Vector3(0, 0.70, 0), _emat(Color(0.45, 0.80, 0.90), 0.8), root)
			for b in [Vector3(0.3, 0.73, 0.2), Vector3(-0.25, 0.73, -0.3),
					Vector3(-0.1, 0.73, 0.35), Vector3(0.2, 0.73, -0.15)]:
				_sph(0.035, b, white, root)
			office._box(Vector3(0.55, 0.18, 0.32), Vector3(0, 0.09, 1.10), wood, root, false)
			_omni(Vector3(0, 0.9, 0), Color(0.55, 0.85, 1.0), 0.6, 2.0, root)
		"desk_stand":
			var wtop: StandardMaterial3D = office._mat("sp_oak", Color(0.72, 0.60, 0.45))
			for fx in [-0.60, 0.60]:
				office._box(Vector3(0.12, 0.05, 0.62), Vector3(fx, 0.025, 0), white, root, false)
				office._box(Vector3(0.08, 1.00, 0.08), Vector3(fx, 0.55, 0), white, root, false)
			office._box(Vector3(1.40, 0.04, 0.70), Vector3(0, 1.07, 0), wtop, root, false)
			office._box(Vector3(0.55, 0.32, 0.03), Vector3(0, 1.32, -0.18),
				_emat(Color(0.18, 0.30, 0.45), 0.7), root, false)
			office._box(Vector3(0.12, 0.13, 0.04), Vector3(0, 1.15, -0.20), black, root, false)
			office._box(Vector3(0.35, 0.02, 0.12), Vector3(0, 1.10, 0.12), black, root, false)
			office._box(Vector3(0.08, 0.04, 0.10), Vector3(0.62, 1.04, 0.28), black, root, false)
		"booth":
			var pod: StandardMaterial3D = office._mat("sp_pod", Color(0.13, 0.27, 0.22))
			office._box(Vector3(1.10, 0.08, 1.10), Vector3(0, 0.04, 0), pod, root, false)
			office._box(Vector3(1.10, 2.10, 0.08), Vector3(0, 1.13, -0.51), pod, root, false)
			for sx in [-0.51, 0.51]:
				office._box(Vector3(0.08, 2.10, 1.10), Vector3(sx, 1.13, 0), pod, root, false)
			office._box(Vector3(1.10, 0.10, 1.10), Vector3(0, 2.23, 0), pod, root, false)
			office._box(Vector3(0.94, 1.95, 0.03), Vector3(0, 1.10, 0.52), _glass_mat(), root, false)
			office._box(Vector3(0.06, 1.95, 0.05), Vector3(-0.50, 1.10, 0.52), black, root, false)
			office._box(Vector3(0.70, 0.35, 0.35), Vector3(0, 0.55, -0.28),
				office._mat("sp_podseat", Color(0.85, 0.55, 0.35)), root, false)
			office._box(Vector3(0.50, 0.03, 0.25), Vector3(0, 1.05, -0.35), wood, root, false)
			office._box(Vector3(0.30, 0.06, 0.02), Vector3(0, 2.0, 0.54),
				_emat(Color(0.95, 0.95, 0.90), 1.0), root, false)
			_omni(Vector3(0, 1.9, 0), Color(1.0, 0.88, 0.70), 0.7, 1.3, root)
		"cooler":
			office._box(Vector3(0.36, 0.95, 0.36), Vector3(0, 0.475, 0), white, root, false)
			_cyl(0.145, 0.145, 0.38, Vector3(0, 1.16, 0),
				_glass_mat(Color(0.45, 0.70, 0.90, 0.45)), root)
			_cyl(0.12, 0.12, 0.30, Vector3(0, 1.12, 0), _emat(Color(0.55, 0.78, 0.95), 0.5), root)
			office._box(Vector3(0.05, 0.05, 0.06), Vector3(-0.08, 0.78, 0.19),
				office._mat("sp_tapblue", Color(0.25, 0.45, 0.85)), root, false)
			office._box(Vector3(0.05, 0.05, 0.06), Vector3(0.08, 0.78, 0.19),
				office._mat("sp_tapred", Color(0.85, 0.25, 0.25)), root, false)
			office._box(Vector3(0.30, 0.06, 0.30), Vector3(0, 0.66, 0.04), black, root, false)
		"vending":
			var vred: StandardMaterial3D = office._mat("sp_vend", Color(0.72, 0.16, 0.18))
			office._box(Vector3(0.90, 1.80, 0.70), Vector3(0, 0.90, 0), vred, root, false)
			office._box(Vector3(0.52, 1.15, 0.03), Vector3(-0.12, 1.05, 0.36), _glass_mat(), root, false)
			for row in 3:
				office._box(Vector3(0.48, 0.02, 0.08), Vector3(-0.12, 0.72 + row * 0.38, 0.32),
					white, root, false)
				for col in 3:
					office._box(Vector3(0.10, 0.16, 0.06),
						Vector3(-0.28 + col * 0.16, 0.83 + row * 0.38, 0.32),
						_emat([Color(0.95, 0.65, 0.20), Color(0.30, 0.70, 0.45),
							Color(0.40, 0.55, 0.90)][(row + col) % 3], 0.4), root, false)
			office._box(Vector3(0.18, 0.30, 0.03), Vector3(0.30, 1.30, 0.36), black, root, false)
			office._box(Vector3(0.12, 0.06, 0.02), Vector3(0.30, 1.42, 0.37),
				_emat(Color(0.45, 0.85, 0.60), 1.2), root, false)
			office._box(Vector3(0.40, 0.12, 0.03), Vector3(-0.12, 0.32, 0.36), black, root, false)
			office._box(Vector3(0.70, 0.10, 0.02), Vector3(0, 1.72, 0.36),
				_emat(Color(0.95, 0.92, 0.85), 1.4), root, false)
			_omni(Vector3(0, 1.2, 0.6), Color(0.9, 0.95, 1.0), 0.6, 1.8, root)
		"copier":
			var lgray: StandardMaterial3D = office._mat("sp_lgray", Color(0.80, 0.80, 0.78))
			office._box(Vector3(0.90, 0.42, 0.55), Vector3(0, 0.21, 0), lgray, root, false)
			office._box(Vector3(0.95, 0.45, 0.60), Vector3(0, 0.66, 0), white, root, false)
			office._box(Vector3(0.90, 0.06, 0.55), Vector3(0, 0.92, 0), black, root, false)
			var cpanel: MeshInstance3D = office._box(Vector3(0.30, 0.02, 0.16),
				Vector3(0.25, 0.90, 0.24), _emat(Color(0.35, 0.75, 0.72), 0.8), root, false)
			cpanel.rotation_degrees = Vector3(-18, 0, 0)
			office._box(Vector3(0.35, 0.03, 0.30), Vector3(-0.18, 0.50, 0.30), lgray, root, false)
			office._box(Vector3(0.30, 0.02, 0.22), Vector3(-0.15, 0.53, 0.28), white, root, false)
			_sph(0.015, Vector3(0.42, 0.80, 0.28), _emat(Color(0.3, 0.9, 0.4), 2.0), root)
		"wboard":
			for sx in [-0.72, 0.72]:
				var lg1: MeshInstance3D = office._box(Vector3(0.05, 1.75, 0.05),
					Vector3(sx, 0.87, 0.16), metal, root, false)
				lg1.rotation_degrees = Vector3(10, 0, 0)
				var lg2: MeshInstance3D = office._box(Vector3(0.05, 1.75, 0.05),
					Vector3(sx, 0.87, -0.16), metal, root, false)
				lg2.rotation_degrees = Vector3(-10, 0, 0)
				for cz in [-0.30, 0.30]:
					_sph(0.045, Vector3(sx, 0.045, cz), black, root)
			office._box(Vector3(1.60, 1.00, 0.04), Vector3(0, 1.25, 0), white, root, false)
			office._box(Vector3(1.64, 1.04, 0.02), Vector3(0, 1.25, -0.012), metal, root, false)
			var strokes := [[Color(0.85, 0.25, 0.25), Vector3(-0.45, 1.50, 0.025), 0.45, -6.0],
				[Color(0.25, 0.35, 0.80), Vector3(-0.30, 1.30, 0.025), 0.6, 4.0],
				[Color(0.15, 0.15, 0.18), Vector3(0.30, 1.42, 0.025), 0.5, -3.0],
				[Color(0.15, 0.15, 0.18), Vector3(0.35, 1.12, 0.025), 0.35, 8.0]]
			for st in strokes:
				var sm: MeshInstance3D = office._box(Vector3(st[2], 0.025, 0.005), st[1],
					office._mat("sp_ink%02x" % int(st[0].r * 99), st[0]), root, false)
				sm.rotation_degrees = Vector3(0, 0, st[3])
			office._box(Vector3(0.60, 0.03, 0.10), Vector3(0, 0.72, 0.06), metal, root, false)
			office._box(Vector3(0.10, 0.03, 0.03), Vector3(-0.15, 0.755, 0.06),
				office._mat("sp_tapred", Color(0.85, 0.25, 0.25)), root, false)
		"locker":
			var steelb: StandardMaterial3D = office._mat("sp_locker_" + str(params.get("col", "617b9e")), Color.html(str(params.get("col", "617b9e"))))
			office._box(Vector3(1.20, 1.80, 0.50), Vector3(0, 0.90, 0), steelb, root, false)
			for dx in [-0.20, 0.20]:
				office._box(Vector3(0.015, 1.70, 0.02), Vector3(dx, 0.90, 0.25), black, root, false)
			for i in 3:
				var lx := -0.40 + i * 0.40
				for v in 3:
					office._box(Vector3(0.22, 0.015, 0.02), Vector3(lx, 1.52 - v * 0.07, 0.25),
						black, root, false)
				office._box(Vector3(0.03, 0.10, 0.03), Vector3(lx + 0.13, 1.05, 0.26),
					metal, root, false)
		"conftable":
			var wtop2: StandardMaterial3D = office._mat("sp_oak", Color(0.72, 0.60, 0.45))
			office._box(Vector3(2.00, 0.06, 1.20), Vector3(0, 0.74, 0), wtop2, root, false)
			for ex in [-1.0, 1.0]:
				_cyl(0.60, 0.60, 0.06, Vector3(ex, 0.74, 0), wtop2, root)
			for cx in [-0.75, 0.75]:
				_cyl(0.07, 0.07, 0.68, Vector3(cx, 0.37, 0), black, root)
				office._box(Vector3(0.55, 0.04, 0.55), Vector3(cx, 0.02, 0), black, root, false)
			_cyl(0.10, 0.10, 0.03, Vector3(0, 0.785, 0), black, root)
			office._box(Vector3(0.25, 0.01, 0.30), Vector3(0.5, 0.775, 0.2), white, root, false)
		"trophy":
			office._box(Vector3(1.00, 1.60, 0.40), Vector3(0, 0.80, 0), dwood, root, false)
			office._box(Vector3(0.90, 1.40, 0.30), Vector3(0, 0.85, 0.01), black, root, false)
			office._box(Vector3(0.90, 0.02, 0.30), Vector3(0, 1.15, 0.01), dwood, root, false)
			office._box(Vector3(0.90, 0.02, 0.30), Vector3(0, 0.70, 0.01), dwood, root, false)
			var gold := _emat(Color(0.95, 0.78, 0.30), 0.7)
			var spots := [Vector3(-0.25, 1.22, 0.05), Vector3(0.15, 1.22, 0.05),
				Vector3(-0.10, 0.77, 0.05), Vector3(0.28, 0.77, 0.05), Vector3(-0.05, 0.32, 0.05)]
			for i in spots.size():
				_cyl(0.055, 0.035, 0.05, spots[i], gold, root)
				_sph(0.045, spots[i] + Vector3(0, 0.075, 0), gold, root)
			office._box(Vector3(0.94, 1.44, 0.02), Vector3(0, 0.85, 0.19), _glass_mat(), root, false)
			_omni(Vector3(0, 1.35, 0.1), Color(1.0, 0.85, 0.55), 0.6, 1.2, root)
		"pingpong":
			var ptop: StandardMaterial3D = office._mat("sp_pp", Color(0.16, 0.35, 0.58))
			office._box(Vector3(2.40, 0.04, 1.35), Vector3(0, 0.76, 0), ptop, root, false)
			office._box(Vector3(2.40, 0.005, 0.03), Vector3(0, 0.783, 0), white, root, false)
			for ez in [-0.66, 0.66]:
				office._box(Vector3(2.40, 0.005, 0.025), Vector3(0, 0.783, ez), white, root, false)
			for ex in [-1.19, 1.19]:
				office._box(Vector3(0.025, 0.005, 1.35), Vector3(ex, 0.783, 0), white, root, false)
			office._box(Vector3(0.03, 0.15, 1.42), Vector3(0, 0.855, 0),
				office._mat("sp_net", Color(0.25, 0.26, 0.28)), root, false)
			office._box(Vector3(0.03, 0.015, 1.42), Vector3(0, 0.925, 0), white, root, false)
			for lx in [-0.95, 0.95]:
				for lz in [-0.50, 0.50]:
					var pl: MeshInstance3D = office._box(Vector3(0.06, 0.76, 0.06),
						Vector3(lx, 0.38, lz), black, root, false)
					pl.rotation_degrees = Vector3(0, 0, 4.0 * signf(lx))
			var pdl: MeshInstance3D = _cyl(0.085, 0.085, 0.012, Vector3(-0.7, 0.79, 0.3),
				office._mat("sp_pdlred", Color(0.80, 0.20, 0.20)), root)
			pdl.rotation_degrees = Vector3(0, 0, 90)
			pdl.rotation_degrees = Vector3(90, 25, 0)
			var pdl2: MeshInstance3D = _cyl(0.085, 0.085, 0.012, Vector3(0.65, 0.79, -0.35),
				black, root)
			pdl2.rotation_degrees = Vector3(90, -30, 0)
			_sph(0.022, Vector3(0.2, 0.80, 0.15), white, root)
		"server":
			office._box(Vector3(0.60, 1.90, 0.80), Vector3(0, 0.95, 0), black, root, false)
			for u in 6:
				office._box(Vector3(0.52, 0.16, 0.02), Vector3(0, 0.35 + u * 0.28, 0.41),
					office._mat("sp_srv", Color(0.22, 0.23, 0.26)), root, false)
				for led in 3:
					_sph(0.012, Vector3(-0.18 + led * 0.07, 0.38 + u * 0.28, 0.425),
						_emat([Color(0.3, 0.9, 0.4), Color(0.95, 0.75, 0.2),
							Color(0.3, 0.9, 0.4)][(u + led) % 3], 2.2), root)
			_omni(Vector3(0, 1.0, 0.5), Color(0.4, 0.9, 0.5), 0.35, 1.2, root)
		"clock":
			office._box(Vector3(0.36, 1.90, 0.26), Vector3(0, 0.95, 0), dwood, root, false)
			_cyl(0.145, 0.145, 0.02, Vector3(0, 1.55, 0.13), white, root, Vector3(90, 0, 0))
			office._box(Vector3(0.012, 0.10, 0.005), Vector3(0, 1.58, 0.145), black, root, false)
			var mh: MeshInstance3D = office._box(Vector3(0.012, 0.08, 0.005),
				Vector3(0.025, 1.555, 0.145), black, root, false)
			mh.rotation_degrees = Vector3(0, 0, -55)
			office._box(Vector3(0.24, 0.85, 0.02), Vector3(0, 0.62, 0.13),
				_glass_mat(Color(0.72, 0.84, 0.90, 0.18)), root, false)
			_cyl(0.008, 0.008, 0.55, Vector3(0, 0.85, 0.08),
				office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root)
			_cyl(0.06, 0.06, 0.015, Vector3(0, 0.55, 0.08),
				_emat(Color(0.95, 0.80, 0.40), 0.5), root, Vector3(90, 0, 0))
		"desk_scandi":
			# IKEA-inspired white frame desk: closed-loop side legs, clean top
			for sx in [-0.58, 0.58]:
				office._box(Vector3(0.05, 0.70, 0.05), Vector3(sx, 0.35, -0.25), white, root, false)
				office._box(Vector3(0.05, 0.70, 0.05), Vector3(sx, 0.35, 0.25), white, root, false)
				office._box(Vector3(0.05, 0.05, 0.55), Vector3(sx, 0.03, 0), white, root, false)
			office._box(Vector3(1.24, 0.05, 0.60), Vector3(0, 0.725, 0), white, root, false)
			office._box(Vector3(0.34, 0.24, 0.52), Vector3(0.42, 0.58, 0), white, root, false)
			office._box(Vector3(0.30, 0.015, 0.02), Vector3(0.42, 0.60, 0.265), black, root, false)
		"drawer7":
			office._box(Vector3(0.36, 1.02, 0.48), Vector3(0, 0.53, 0), white, root, false)
			office._box(Vector3(0.40, 0.03, 0.52), Vector3(0, 1.06, 0), white, root, false)
			office._box(Vector3(0.40, 0.03, 0.52), Vector3(0, 0.015, 0), white, root, false)
			for d in 7:
				office._box(Vector3(0.32, 0.012, 0.015), Vector3(0, 0.13 + d * 0.135, 0.245),
					office._mat("sp_seam", Color(0.78, 0.78, 0.76)), root, false)
		"chair_scandi":
			var ply: StandardMaterial3D = office._mat("sp_ply", Color(0.78, 0.66, 0.48))
			for i in 5:
				var ang := i * TAU / 5.0
				var sl: MeshInstance3D = office._box(Vector3(0.26, 0.03, 0.045),
					Vector3(cos(ang) * 0.125, 0.05, sin(ang) * 0.125), metal, root, false)
				sl.rotation_degrees = Vector3(0, -rad_to_deg(ang), 0)
				_sph(0.028, Vector3(cos(ang) * 0.24, 0.028, sin(ang) * 0.24), black, root)
			_cyl(0.025, 0.025, 0.32, Vector3(0, 0.24, 0), metal, root)
			office._box(Vector3(0.44, 0.05, 0.44), Vector3(0, 0.44, 0), white, root, false)
			var bk: MeshInstance3D = office._box(Vector3(0.42, 0.52, 0.03),
				Vector3(0, 0.72, -0.21), ply, root, false)
			bk.rotation_degrees = Vector3(-8, 0, 0)
			var pad: MeshInstance3D = office._box(Vector3(0.30, 0.38, 0.015),
				Vector3(0, 0.72, -0.185), white, root, false)
			pad.rotation_degrees = Vector3(-8, 0, 0)
		"sideboard":
			var mint := _glass_mat(Color(0.78, 0.88, 0.82, 0.55))
			for lx in [-0.48, 0.48]:
				office._box(Vector3(0.05, 0.12, 0.05), Vector3(lx, 0.06, 0.15), white, root, false)
				office._box(Vector3(0.05, 0.12, 0.05), Vector3(lx, 0.06, -0.15), white, root, false)
			office._box(Vector3(1.10, 0.72, 0.42), Vector3(0, 0.48, 0), white, root, false)
			for dx in [-0.26, 0.26]:
				office._box(Vector3(0.44, 0.56, 0.02), Vector3(dx, 0.48, 0.215), mint, root, false)
			office._box(Vector3(0.015, 0.60, 0.03), Vector3(0, 0.48, 0.215),
				office._mat("sp_seam", Color(0.78, 0.78, 0.76)), root, false)
			office._box(Vector3(1.14, 0.03, 0.46), Vector3(0, 0.855, 0), white, root, false)
		"wallclock":
			_cyl(0.17, 0.17, 0.035, Vector3(0, 0.15, 0), white, root, Vector3(90, 0, 0))
			_cyl(0.175, 0.175, 0.015, Vector3(0, 0.15, -0.012), black, root, Vector3(90, 0, 0))
			office._box(Vector3(0.012, 0.11, 0.006), Vector3(0, 0.20, 0.02), black, root, false)
			var mnh: MeshInstance3D = office._box(Vector3(0.012, 0.085, 0.006),
				Vector3(0.03, 0.155, 0.02), black, root, false)
			mnh.rotation_degrees = Vector3(0, 0, -65)
		"chalkboard":
			var frame: StandardMaterial3D = office._mat("sp_ply", Color(0.78, 0.66, 0.48))
			office._box(Vector3(1.34, 0.94, 0.03), Vector3(0, 1.32, 0), frame, root, false)
			office._box(Vector3(1.22, 0.82, 0.02), Vector3(0, 1.32, 0.012),
				office._mat("sp_slate", Color(0.13, 0.14, 0.15)), root, false)
			var chalk := [[Vector3(-0.35, 1.58, 0.03), 0.42, -5.0], [Vector3(-0.25, 1.44, 0.03), 0.30, 3.0],
				[Vector3(0.20, 1.30, 0.03), 0.38, -2.0], [Vector3(0.30, 1.14, 0.03), 0.25, 6.0]]
			for ck in chalk:
				var cm: MeshInstance3D = office._box(Vector3(ck[1], 0.018, 0.004), ck[0],
					white, root, false)
				cm.rotation_degrees = Vector3(0, 0, ck[2])
			for plx in [-0.60, 0.60]:
				office._box(Vector3(0.06, 1.75, 0.06), Vector3(plx, 0.87, 0), frame, root, false)
		"corkboard":
			office._box(Vector3(0.90, 0.66, 0.03), Vector3(0, 1.45, 0), white, root, false)
			office._box(Vector3(0.82, 0.58, 0.02), Vector3(0, 1.45, 0.012),
				office._mat("sp_cork", Color(0.80, 0.66, 0.44)), root, false)
			var notes := [[Color(0.98, 0.97, 0.92), Vector3(-0.25, 1.55, 0.028), 7.0],
				[Color(0.95, 0.88, 0.55), Vector3(0.05, 1.48, 0.028), -4.0],
				[Color(0.85, 0.92, 0.95), Vector3(0.26, 1.56, 0.028), 3.0],
				[Color(0.98, 0.97, 0.92), Vector3(0.12, 1.32, 0.028), -8.0]]
			for nt in notes:
				var nm: MeshInstance3D = office._box(Vector3(0.12, 0.14, 0.005), nt[1],
					office._mat("sp_note%02x" % int(nt[0].g * 99), nt[0]), root, false)
				nm.rotation_degrees = Vector3(0, 0, nt[2])
			for plx2 in [-0.38, 0.38]:
				office._box(Vector3(0.05, 1.80, 0.05), Vector3(plx2, 0.90, 0), white, root, false)
		"flipclock":
			office._box(Vector3(0.17, 0.095, 0.06), Vector3(0, 0.055, 0), black, root, false)
			office._box(Vector3(0.065, 0.065, 0.005), Vector3(-0.038, 0.055, 0.031),
				_emat(Color(0.96, 0.95, 0.90), 0.5), root, false)
			office._box(Vector3(0.065, 0.065, 0.005), Vector3(0.038, 0.055, 0.031),
				_emat(Color(0.96, 0.95, 0.90), 0.5), root, false)
			office._box(Vector3(0.17, 0.004, 0.062), Vector3(0, 0.055, 0.0), metal, root, false)
		"magfiles":
			for i in 3:
				office._box(Vector3(0.075, 0.25, 0.24), Vector3(-0.10 + i * 0.10, 0.125, 0), black, root, false)
				office._box(Vector3(0.055, 0.22, 0.20), Vector3(-0.10 + i * 0.10, 0.15, 0), white, root, false)
		"tulip":
			_cyl(0.075, 0.055, 0.11, Vector3(0, 0.055, 0), white, root)
			var stem: StandardMaterial3D = office._mat("sp_stem", Color(0.35, 0.55, 0.30))
			var heads := [Color(0.92, 0.45, 0.60), Color(0.95, 0.55, 0.68), Color(0.88, 0.38, 0.55)]
			for i in 3:
				var hx := -0.03 + i * 0.03
				var tst: MeshInstance3D = office._box(Vector3(0.008, 0.20, 0.008),
					Vector3(hx, 0.20, i * 0.02 - 0.02), stem, root, false)
				tst.rotation_degrees = Vector3(0, 0, i * 8.0 - 8.0)
				_sph(0.028, Vector3(hx * 1.8, 0.31, i * 0.03 - 0.03),
					office._mat("sp_tul%d" % i, heads[i]), root)
		"basket":
			_cyl(0.16, 0.13, 0.32, Vector3(0, 0.16, 0), white, root)
			_cyl(0.165, 0.165, 0.05, Vector3(0, 0.30, 0),
				office._mat("sp_bask", Color(0.25, 0.27, 0.30)), root)
			_cyl(0.14, 0.12, 0.02, Vector3(0, 0.325, 0), black, root)
		"globe":
			_cyl(0.06, 0.09, 0.03, Vector3(0, 0.015, 0), dwood, root)
			_cyl(0.012, 0.012, 0.10, Vector3(0, 0.08, 0), metal, root)
			_sph(0.115, Vector3(0, 0.23, 0), office._mat("sp_sea", Color(0.25, 0.45, 0.70)), root)
			for patch in [Vector3(0.06, 0.28, 0.06), Vector3(-0.07, 0.20, 0.04), Vector3(0.02, 0.17, -0.08)]:
				_sph(0.045, patch, office._mat("sp_land", Color(0.40, 0.60, 0.35)), root)
		"printer":
			office._box(Vector3(0.44, 0.16, 0.34), Vector3(0, 0.08, 0), white, root, false)
			office._box(Vector3(0.40, 0.05, 0.28), Vector3(0, 0.185, 0),
				office._mat("sp_mint", Color(0.72, 0.83, 0.75)), root, false)
			office._box(Vector3(0.30, 0.02, 0.04), Vector3(0, 0.10, 0.175), black, root, false)
			office._box(Vector3(0.24, 0.005, 0.16), Vector3(0, 0.215, -0.02), white, root, false)
			_sph(0.012, Vector3(0.16, 0.17, 0.16), _emat(Color(0.3, 0.9, 0.4), 1.6), root)
		"tulip_table":
			_cyl(0.26, 0.30, 0.04, Vector3(0, 0.02, 0), white, root)
			_cyl(0.05, 0.16, 0.30, Vector3(0, 0.19, 0), white, root)
			_cyl(0.05, 0.05, 0.34, Vector3(0, 0.45, 0), white, root)
			_cyl(0.40, 0.34, 0.04, Vector3(0, 0.72, 0), white, root)
		"cafe_chair":
			var cc: StandardMaterial3D = office._mat("sp_cafe_" + str(params.get("col", "d9b23a")),
				Color.html(str(params.get("col", "d9b23a"))))
			for sx2 in [-0.20, 0.20]:
				office._box(Vector3(0.03, 0.44, 0.03), Vector3(sx2, 0.22, 0.18), cc, root, false)
				var rear: MeshInstance3D = office._box(Vector3(0.03, 0.80, 0.03),
					Vector3(sx2, 0.40, -0.19), cc, root, false)
				rear.rotation_degrees = Vector3(6, 0, 0)
				var arm: MeshInstance3D = office._box(Vector3(0.03, 0.03, 0.42),
					Vector3(sx2, 0.45, 0.0), cc, root, false)
				arm.rotation_degrees = Vector3(0, 0, 0)
			office._box(Vector3(0.42, 0.035, 0.40), Vector3(0, 0.44, 0), cc, root, false)
			var top_rail: MeshInstance3D = office._box(Vector3(0.46, 0.035, 0.06),
				Vector3(0, 0.80, -0.235), cc, root, false)
			top_rail.rotation_degrees = Vector3(6, 0, 0)
			office._box(Vector3(0.42, 0.16, 0.025), Vector3(0, 0.66, -0.215), cc, root, false)
		"griddiv":
			office._box(Vector3(1.00, 0.05, 0.05), Vector3(0, 1.90, 0), black, root, false)
			office._box(Vector3(1.00, 0.05, 0.05), Vector3(0, 0.15, 0), black, root, false)
			for fx2 in [-0.50, 0.50]:
				office._box(Vector3(0.05, 1.85, 0.05), Vector3(fx2, 1.02, 0), black, root, false)
				office._box(Vector3(0.05, 0.05, 0.55), Vector3(fx2, 0.025, 0), black, root, false)
			for gv in 5:
				office._box(Vector3(0.012, 1.70, 0.012), Vector3(-0.34 + gv * 0.17, 1.02, 0),
					black, root, false)
			for gh in 9:
				office._box(Vector3(0.90, 0.012, 0.012), Vector3(0, 0.28 + gh * 0.17, 0),
					black, root, false)
		"poster":
			var pcol := Color.html(str(params.get("col", "2a9d8f")))
			office._box(Vector3(0.56, 0.96, 0.02), Vector3(0, 0.20, 0), black, root, false)
			office._box(Vector3(0.52, 0.92, 0.01), Vector3(0, 0.20, 0.011),
				office._mat("sp_pos_" + str(params.get("col", "")), pcol), root, false)
			_cyl(0.14, 0.14, 0.008, Vector3(0, 0.30, 0.02), white, root, Vector3(90, 0, 0))
			office._box(Vector3(0.30, 0.02, 0.005), Vector3(0, -0.10, 0.02), white, root, false)
			office._box(Vector3(0.20, 0.02, 0.005), Vector3(0, -0.16, 0.02), white, root, false)
		"drumtable":
			_cyl(0.20, 0.20, 0.55, Vector3(0, 0.275, 0), white, root)
			_cyl(0.21, 0.21, 0.02, Vector3(0, 0.56, 0), white, root)
		_:
			if not _spawn_extra(id, params, root):
				root.queue_free()
				return null
	return root


## Expansion packs (wave 1): seating, tables, storage, lighting, plants,
## wall structures — all original procedural pieces. Returns false when
## the id is unknown so the caller can clean up.
func _spawn_extra(id: String, params: Dictionary, root: Node3D) -> bool:
	var wood: StandardMaterial3D = office._mat("sp_wood", Color(0.55, 0.42, 0.30))
	var dwood: StandardMaterial3D = office._mat("sp_dwood", Color(0.33, 0.25, 0.19))
	var metal: StandardMaterial3D = office._mat("sp_metal", Color(0.46, 0.47, 0.50))
	var white: StandardMaterial3D = office._mat("sp_white", Color(0.94, 0.93, 0.90))
	var black: StandardMaterial3D = office._mat("sp_black", Color(0.10, 0.10, 0.12))
	var green: StandardMaterial3D = office._mat("sp_leaf", Color(0.32, 0.52, 0.30))
	var dgreen: StandardMaterial3D = office._mat("sp_leafd", Color(0.22, 0.40, 0.24))
	var pot: StandardMaterial3D = office._mat("sp_pot", Color(0.78, 0.60, 0.48))
	var ply: StandardMaterial3D = office._mat("sp_ply", Color(0.78, 0.66, 0.48))
	var pchex := str(params.get("col", "cccccc"))
	var pm: StandardMaterial3D = office._mat("sp_c_" + pchex, Color.html(pchex))
	match id:
		# ------------------------------------------------------ seating
		"beanbag":
			var bb := _sph(0.42, Vector3(0, 0.27, 0), pm, root)
			bb.scale = Vector3(1, 0.62, 1)
			var bt := _sph(0.24, Vector3(0, 0.46, -0.06), pm, root)
			bt.scale = Vector3(1, 0.55, 1)
		"ottoman":
			office._box(Vector3(0.55, 0.30, 0.55), Vector3(0, 0.19, 0), pm, root, false)
			office._box(Vector3(0.58, 0.05, 0.58), Vector3(0, 0.36, 0), pm, root, false)
			for lx in [-0.22, 0.22]:
				for lz in [-0.22, 0.22]:
					office._box(Vector3(0.04, 0.08, 0.04), Vector3(lx, 0.04, lz), dwood, root, false)
		"bench_wood":
			office._box(Vector3(1.40, 0.06, 0.35), Vector3(0, 0.45, 0), wood, root, false)
			for lx in [-0.60, 0.60]:
				for tz in [[0.10, 8.0], [-0.10, -8.0]]:
					var bl: MeshInstance3D = office._box(Vector3(0.05, 0.46, 0.05),
						Vector3(lx, 0.22, tz[0]), black, root, false)
					bl.rotation_degrees = Vector3(tz[1], 0, 0)
		"sofa_l":
			office._box(Vector3(2.20, 0.30, 0.85), Vector3(0, 0.27, 0), pm, root, false)
			office._box(Vector3(0.85, 0.30, 0.85), Vector3(0.675, 0.27, 0.85), pm, root, false)
			office._box(Vector3(2.20, 0.45, 0.16), Vector3(0, 0.62, -0.35), pm, root, false)
			office._box(Vector3(0.16, 0.45, 1.70), Vector3(1.02, 0.62, 0.42), pm, root, false)
			for cx in [-0.65, 0.05]:
				office._box(Vector3(0.62, 0.10, 0.60), Vector3(cx, 0.47, 0.02), pm, root, false)
			office._box(Vector3(0.60, 0.10, 0.75), Vector3(0.67, 0.47, 0.80), pm, root, false)
			office._box(Vector3(0.30, 0.28, 0.10), Vector3(-0.6, 0.55, -0.26), white, root, false)
		"stool_round":
			_cyl(0.19, 0.19, 0.09, Vector3(0, 0.42, 0), pm, root)
			for i in 3:
				var ang := i * TAU / 3.0
				var sl: MeshInstance3D = office._box(Vector3(0.04, 0.44, 0.04),
					Vector3(cos(ang) * 0.12, 0.20, sin(ang) * 0.12), wood, root, false)
				sl.rotation_degrees = Vector3(cos(ang) * -10.0, 0, sin(ang) * -10.0)
		"wing":
			office._box(Vector3(0.72, 0.16, 0.66), Vector3(0, 0.28, 0), pm, root, false)
			office._box(Vector3(0.60, 0.10, 0.55), Vector3(0, 0.39, 0.02), pm, root, false)
			office._box(Vector3(0.72, 0.85, 0.15), Vector3(0, 0.70, -0.27), pm, root, false)
			for wx in [-0.34, 0.34]:
				var wg: MeshInstance3D = office._box(Vector3(0.10, 0.62, 0.40),
					Vector3(wx, 0.72, -0.10), pm, root, false)
				wg.rotation_degrees = Vector3(0, wx * -22.0, 0)
				office._box(Vector3(0.04, 0.20, 0.04), Vector3(wx, 0.10, 0.24), dwood, root, false)
				office._box(Vector3(0.04, 0.20, 0.04), Vector3(wx, 0.10, -0.24), dwood, root, false)
		# ------------------------------------------------------- tables
		"table_std":
			var w := float(params.get("w", 1.6))
			var d := float(params.get("d", 0.9))
			var tmat: StandardMaterial3D = white
			match str(params.get("top", "wood")):
				"wood": tmat = office._mat("sp_ply", Color(0.78, 0.66, 0.48))
				"black": tmat = black
				"marble": tmat = office._mat("sp_marble", Color(0.90, 0.89, 0.86))
			office._box(Vector3(w, 0.05, d), Vector3(0, 0.73, 0), tmat, root, false)
			for lx in [-w / 2.0 + 0.08, w / 2.0 - 0.08]:
				for lz in [-d / 2.0 + 0.08, d / 2.0 - 0.08]:
					_cyl(0.03, 0.03, 0.72, Vector3(lx, 0.36, lz), black, root)
		"desk_l":
			office._box(Vector3(1.60, 0.05, 0.70), Vector3(0, 0.72, 0), pm, root, false)
			office._box(Vector3(0.70, 0.05, 0.90), Vector3(-0.45, 0.72, 0.80), pm, root, false)
			for lp in [Vector3(-0.72, 0.36, -0.28), Vector3(0.72, 0.36, -0.28), Vector3(0.72, 0.36, 0.28),
					Vector3(-0.72, 0.36, 1.18), Vector3(-0.18, 0.36, 1.18)]:
				office._box(Vector3(0.06, 0.70, 0.06), lp, black, root, false)
		"desk_glass":
			office._box(Vector3(1.40, 0.03, 0.70), Vector3(0, 0.73, 0), _glass_mat(), root, false)
			for lx in [-0.64, 0.64]:
				office._box(Vector3(0.05, 0.72, 0.62), Vector3(lx, 0.36, 0), black, root, false)
			office._box(Vector3(1.28, 0.10, 0.04), Vector3(0, 0.20, -0.25), black, root, false)
		"desk_exec":
			office._box(Vector3(1.80, 0.06, 0.90), Vector3(0, 0.74, 0), dwood, root, false)
			for px in [-0.72, 0.72]:
				office._box(Vector3(0.36, 0.68, 0.80), Vector3(px, 0.36, 0), dwood, root, false)
				for dr in 3:
					office._box(Vector3(0.30, 0.015, 0.02), Vector3(px, 0.18 + dr * 0.20, 0.41),
						office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root, false)
			office._box(Vector3(1.10, 0.55, 0.05), Vector3(0, 0.42, -0.38), dwood, root, false)
		"picnic":
			office._box(Vector3(1.80, 0.05, 0.75), Vector3(0, 0.72, 0), wood, root, false)
			for bz in [-0.62, 0.62]:
				office._box(Vector3(1.80, 0.04, 0.25), Vector3(0, 0.44, bz), wood, root, false)
			for lx in [-0.70, 0.70]:
				for ta in [[22.0, 1], [-22.0, -1]]:
					var pl: MeshInstance3D = office._box(Vector3(0.06, 0.78, 0.05),
						Vector3(lx, 0.36, ta[1] * 0.18), wood, root, false)
					pl.rotation_degrees = Vector3(ta[0], 0, 0)
		"table_bar":
			_cyl(0.32, 0.32, 0.04, Vector3(0, 1.04, 0), pm, root)
			_cyl(0.04, 0.04, 1.02, Vector3(0, 0.52, 0), black, root)
			_cyl(0.22, 0.26, 0.03, Vector3(0, 0.015, 0), black, root)
		"coffee_oval":
			var ct := _cyl(0.42, 0.42, 0.04, Vector3(0, 0.40, 0), pm, root)
			ct.scale = Vector3(1.35, 1, 0.8)
			for i in 4:
				var ang := i * TAU / 4.0 + 0.4
				var cl: MeshInstance3D = office._box(Vector3(0.035, 0.40, 0.035),
					Vector3(cos(ang) * 0.40, 0.19, sin(ang) * 0.26), wood, root, false)
				cl.rotation_degrees = Vector3(cos(ang) * 8.0, 0, sin(ang) * -8.0)
		"side_cube":
			office._box(Vector3(0.42, 0.04, 0.42), Vector3(0, 0.40, 0), pm, root, false)
			office._box(Vector3(0.42, 0.04, 0.42), Vector3(0, 0.02, 0), pm, root, false)
			for sx in [-0.19, 0.19]:
				office._box(Vector3(0.04, 0.36, 0.42), Vector3(sx, 0.21, 0), pm, root, false)
			office._box(Vector3(0.34, 0.36, 0.04), Vector3(0, 0.21, -0.19), pm, root, false)
		"folding":
			office._box(Vector3(1.50, 0.035, 0.70), Vector3(0, 0.72, 0), white, root, false)
			for lx in [-0.60, 0.60]:
				for xa in [18.0, -18.0]:
					var fl: MeshInstance3D = office._box(Vector3(0.04, 0.74, 0.04),
						Vector3(lx, 0.35, 0), metal, root, false)
					fl.rotation_degrees = Vector3(xa, 0, 0)
		# ------------------------------------------------------ storage
		"shelf_cube":
			var nx := int(params.get("n", 2))
			var cw := nx * 0.38
			for r2 in 3:
				office._box(Vector3(cw, 0.03, 0.38), Vector3(0, 0.02 + r2 * 0.38, 0), white, root, false)
			for c2 in nx + 1:
				office._box(Vector3(0.03, 0.79, 0.38), Vector3(-cw / 2.0 + c2 * 0.38, 0.40, 0),
					white, root, false)
			office._box(Vector3(0.30, 0.28, 0.30), Vector3(-cw / 2.0 + 0.19, 0.21, 0),
				office._mat("sp_bin1", Color(0.62, 0.67, 0.57)), root, false)
			office._box(Vector3(0.30, 0.28, 0.30), Vector3(cw / 2.0 - 0.19, 0.59, 0),
				office._mat("sp_bin2", Color(0.80, 0.51, 0.40)), root, false)
		"file_cab":
			var n := int(params.get("n", 2))
			office._box(Vector3(0.45, n * 0.33, 0.55), Vector3(0, n * 0.165 + 0.02, 0), pm, root, false)
			for dr2 in n:
				office._box(Vector3(0.39, 0.26, 0.02), Vector3(0, 0.17 + dr2 * 0.33, 0.28),
					pm, root, false)
				office._box(Vector3(0.16, 0.03, 0.02), Vector3(0, 0.24 + dr2 * 0.33, 0.29),
					black, root, false)
		"wardrobe":
			office._box(Vector3(1.00, 1.90, 0.55), Vector3(0, 0.99, 0), pm, root, false)
			office._box(Vector3(0.015, 1.78, 0.02), Vector3(0, 0.99, 0.28), black, root, false)
			for hx in [-0.08, 0.08]:
				office._box(Vector3(0.03, 0.22, 0.03), Vector3(hx, 1.05, 0.29), black, root, false)
			for fx in [-0.42, 0.42]:
				office._box(Vector3(0.06, 0.08, 0.45), Vector3(fx, 0.0, 0), black, root, false)
		"safe":
			office._box(Vector3(0.55, 0.60, 0.55), Vector3(0, 0.32, 0),
				office._mat("sp_safe", Color(0.25, 0.27, 0.32)), root, false)
			_cyl(0.07, 0.07, 0.04, Vector3(-0.10, 0.38, 0.28), metal, root, Vector3(90, 0, 0))
			office._box(Vector3(0.04, 0.16, 0.03), Vector3(0.14, 0.34, 0.285), metal, root, false)
		"shelf_wall":
			office._box(Vector3(0.90, 0.04, 0.24), Vector3(0, 0.0, 0), wood, root, false)
			for bx in [-0.32, 0.32]:
				office._box(Vector3(0.04, 0.16, 0.04), Vector3(bx, -0.09, -0.08), black, root, false)
			office._box(Vector3(0.10, 0.16, 0.14), Vector3(-0.25, 0.10, 0), white, root, false)
			office._box(Vector3(0.24, 0.14, 0.03), Vector3(0.20, 0.09, 0),
				office._mat("sp_bookrow", Color(0.42, 0.52, 0.65)), root, false)
		"crate_stack":
			var cpos := [[Vector3(0, 0.15, 0), 0.0], [Vector3(0.05, 0.45, 0.03), 14.0],
				[Vector3(-0.03, 0.75, -0.02), -8.0]]
			for cp in cpos:
				var cr: MeshInstance3D = office._box(Vector3(0.48, 0.30, 0.48), cp[0], wood, root, false)
				cr.rotation_degrees = Vector3(0, cp[1], 0)
				var inr: MeshInstance3D = office._box(Vector3(0.40, 0.06, 0.40),
					cp[0] + Vector3(0, 0.13, 0), dwood, root, false)
				inr.rotation_degrees = Vector3(0, cp[1], 0)
		"shelf_ladder":
			for rx in [-0.38, 0.38]:
				var rl: MeshInstance3D = office._box(Vector3(0.05, 1.85, 0.05),
					Vector3(rx, 0.90, -0.02), pm, root, false)
				rl.rotation_degrees = Vector3(-12, 0, 0)
			for sh in 4:
				office._box(Vector3(0.80, 0.03, 0.34 - sh * 0.07),
					Vector3(0, 0.25 + sh * 0.42, -0.30 + sh * 0.115), pm, root, false)
			office._box(Vector3(0.20, 0.20, 0.16), Vector3(-0.2, 0.38, -0.22), white, root, false)
		"box_plastic":
			office._box(Vector3(0.50, 0.32, 0.36), Vector3(0, 0.17, 0),
				_glass_mat(Color.html(pchex) * Color(1, 1, 1, 0.55)), root, false)
			office._box(Vector3(0.53, 0.04, 0.39), Vector3(0, 0.35, 0), white, root, false)
		"shelf_pipe":
			for px2 in [-0.55, 0.55]:
				for pz in [-0.15, 0.15]:
					_cyl(0.02, 0.02, 1.5, Vector3(px2, 0.75, pz), black, root)
			for sh2 in 3:
				office._box(Vector3(1.25, 0.04, 0.38), Vector3(0, 0.25 + sh2 * 0.55, 0), wood, root, false)
		"cart_roll":
			for px3 in [-0.30, 0.30]:
				for pz2 in [-0.18, 0.18]:
					_cyl(0.015, 0.015, 0.85, Vector3(px3, 0.46, pz2), metal, root)
					_sph(0.03, Vector3(px3, 0.03, pz2), black, root)
			for sh3 in 3:
				office._box(Vector3(0.68, 0.03, 0.42), Vector3(0, 0.14 + sh3 * 0.36, 0), metal, root, false)
		# ----------------------------------------------------- lighting
		"pendant":
			_cyl(0.008, 0.008, 0.55, Vector3(0, 2.32, 0), black, root)
			_cyl(0.05, 0.19, 0.18, Vector3(0, 1.96, 0), pm, root)
			_sph(0.045, Vector3(0, 1.90, 0), _emat(Color(1.0, 0.92, 0.75), 1.8), root)
			_omni(Vector3(0, 1.85, 0), Color(1.0, 0.88, 0.68), 1.0, 3.0, root)
		"neon_strip":
			var segs := [[Vector3(-0.28, 0.10, 0), 25.0], [Vector3(0, 0.0, 0), -25.0],
				[Vector3(0.28, 0.10, 0), 25.0]]
			for sg in segs:
				var ns: MeshInstance3D = office._box(Vector3(0.34, 0.035, 0.03), sg[0],
					_emat(Color.html(pchex), 2.2), root, false)
				ns.rotation_degrees = Vector3(0, 0, sg[1])
			_omni(Vector3(0, 0.1, 0.2), Color.html(pchex), 0.9, 2.4, root)
		"string_lights":
			for px4 in [-1.1, 1.1]:
				_cyl(0.025, 0.03, 2.2, Vector3(px4, 1.1, 0), dwood, root)
			for i in 7:
				var t := (i + 1) / 8.0
				var bx2 := -1.1 + t * 2.2
				var by := 2.15 - sin(t * PI) * 0.35
				_sph(0.035, Vector3(bx2, by, 0), _emat(Color(1.0, 0.85, 0.55), 1.8), root)
			_omni(Vector3(0, 1.9, 0), Color(1.0, 0.85, 0.55), 0.8, 3.0, root)
		"lamp_arc":
			office._box(Vector3(0.35, 0.05, 0.35), Vector3(0, 0.025, 0), black, root, false)
			var arcs := [[Vector3(0, 0.75, 0.02), 0.0], [Vector3(0.12, 1.45, 0.02), -28.0],
				[Vector3(0.45, 1.85, 0.02), -64.0]]
			for ac in arcs:
				var ap: MeshInstance3D = _cyl(0.02, 0.02, 0.85, ac[0], metal, root)
				ap.rotation_degrees = Vector3(ac[1], 0, 0)
			_cyl(0.06, 0.15, 0.16, Vector3(0.78, 1.95, 0.02), metal, root, Vector3(0, 0, -30))
			_omni(Vector3(0.78, 1.82, 0.02), Color(1.0, 0.88, 0.68), 1.0, 3.0, root)
		"lamp_tripod":
			for i in 3:
				var ang := i * TAU / 3.0
				var tl: MeshInstance3D = _cyl(0.02, 0.02, 1.15,
					Vector3(cos(ang) * 0.18, 0.55, sin(ang) * 0.18), wood, root)
				tl.rotation_degrees = Vector3(sin(ang) * 16.0, 0, cos(ang) * -16.0)
			_cyl(0.14, 0.18, 0.22, Vector3(0, 1.22, 0), white, root)
			_omni(Vector3(0, 1.18, 0), Color(1.0, 0.88, 0.68), 0.9, 2.6, root)
		"lamp_arm":
			_cyl(0.07, 0.09, 0.03, Vector3(0, 0.015, 0), pm, root)
			var a1: MeshInstance3D = office._box(Vector3(0.025, 0.34, 0.025),
				Vector3(0, 0.17, 0.05), pm, root, false)
			a1.rotation_degrees = Vector3(18, 0, 0)
			var a2: MeshInstance3D = office._box(Vector3(0.025, 0.30, 0.025),
				Vector3(0, 0.42, -0.02), pm, root, false)
			a2.rotation_degrees = Vector3(-35, 0, 0)
			_cyl(0.035, 0.065, 0.09, Vector3(0, 0.54, 0.10), pm, root, Vector3(-40, 0, 0))
			_omni(Vector3(0, 0.48, 0.16), Color(1.0, 0.9, 0.7), 0.5, 1.2, root)
		"lantern":
			var ls := float(params.get("s", 0.2))
			_cyl(0.06, 0.08, 0.03, Vector3(0, 0.015, 0), black, root)
			_cyl(0.015, 0.015, 0.5, Vector3(0, 0.28, 0), black, root)
			_sph(ls, Vector3(0, 0.55 + ls, 0), _emat(Color(0.98, 0.94, 0.86), 0.9), root)
			_omni(Vector3(0, 0.55 + ls, 0), Color(1.0, 0.92, 0.78), 0.8, 2.4, root)
		"softbox":
			_cyl(0.02, 0.02, 1.4, Vector3(0, 0.7, 0), black, root)
			for i in 3:
				var ang := i * TAU / 3.0
				var sl2: MeshInstance3D = _cyl(0.015, 0.015, 0.6,
					Vector3(cos(ang) * 0.22, 0.26, sin(ang) * 0.22), black, root)
				sl2.rotation_degrees = Vector3(sin(ang) * 24.0, 0, cos(ang) * -24.0)
			var sbp: MeshInstance3D = office._box(Vector3(0.60, 0.80, 0.05),
				Vector3(0, 1.55, 0.06), _emat(Color(0.98, 0.97, 0.93), 1.6), root, false)
			sbp.rotation_degrees = Vector3(-12, 0, 0)
			office._box(Vector3(0.66, 0.86, 0.03), Vector3(0, 1.56, 0.015), black, root, false)
			_omni(Vector3(0, 1.5, 0.4), Color(1.0, 0.98, 0.94), 1.2, 3.0, root)
		"ring_light":
			_cyl(0.02, 0.02, 1.5, Vector3(0, 0.75, 0), black, root)
			for i in 3:
				var ang := i * TAU / 3.0
				var rl2: MeshInstance3D = _cyl(0.015, 0.015, 0.55,
					Vector3(cos(ang) * 0.2, 0.24, sin(ang) * 0.2), black, root)
				rl2.rotation_degrees = Vector3(sin(ang) * 24.0, 0, cos(ang) * -24.0)
			var ring := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.20
			tor.outer_radius = 0.26
			ring.mesh = tor
			ring.material_override = _emat(Color(0.98, 0.97, 0.93), 1.8)
			ring.position = Vector3(0, 1.62, 0)
			ring.rotation_degrees = Vector3(90, 0, 0)
			root.add_child(ring)
			_omni(Vector3(0, 1.6, 0.3), Color(1.0, 0.98, 0.94), 1.0, 2.6, root)
		"lamp_mushroom":
			_cyl(0.05, 0.08, 0.20, Vector3(0, 0.10, 0), pm, root)
			var cap := _sph(0.16, Vector3(0, 0.26, 0), pm, root)
			cap.scale = Vector3(1, 0.62, 1)
			_cyl(0.10, 0.10, 0.015, Vector3(0, 0.20, 0), _emat(Color(1.0, 0.9, 0.7), 1.4), root)
			_omni(Vector3(0, 0.18, 0), Color(1.0, 0.88, 0.68), 0.5, 1.2, root)
		"candles":
			office._box(Vector3(0.30, 0.02, 0.14), Vector3(0, 0.01, 0), dwood, root, false)
			var chs := [0.10, 0.15, 0.07]
			for i in 3:
				_cyl(0.028, 0.028, chs[i], Vector3(-0.09 + i * 0.09, 0.02 + chs[i] / 2.0, 0),
					white, root)
				_sph(0.012, Vector3(-0.09 + i * 0.09, 0.045 + chs[i], 0),
					_emat(Color(1.0, 0.72, 0.30), 2.6), root)
			_omni(Vector3(0, 0.25, 0), Color(1.0, 0.72, 0.35), 0.4, 1.0, root)
		"banker":
			_cyl(0.09, 0.11, 0.03, Vector3(0, 0.015, 0),
				office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root)
			_cyl(0.015, 0.015, 0.30, Vector3(0, 0.17, 0),
				office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root)
			var sh4: MeshInstance3D = _cyl(0.16, 0.16, 0.12, Vector3(0, 0.34, 0.05),
				office._mat("sp_bankgreen", Color(0.15, 0.42, 0.28)), root)
			sh4.rotation_degrees = Vector3(90, 0, 0)
			_omni(Vector3(0, 0.28, 0.1), Color(1.0, 0.85, 0.55), 0.5, 1.1, root)
		# ------------------------------------------------------- plants
		"monstera":
			_cyl(0.16, 0.12, 0.28, Vector3(0, 0.14, 0), pm if params.has("col") else pot, root)
			for i in 5:
				var ang := i * TAU / 5.0
				var lf := _sph(0.16, Vector3(cos(ang) * 0.20, 0.55 + (i % 3) * 0.12,
					sin(ang) * 0.20), dgreen, root)
				lf.scale = Vector3(1.1, 0.18, 0.9)
				lf.rotation_degrees = Vector3(sin(ang) * 30.0, rad_to_deg(ang), cos(ang) * 24.0)
				office._box(Vector3(0.015, 0.35, 0.015), Vector3(cos(ang) * 0.09,
					0.38, sin(ang) * 0.09), green, root, false)
		"palm":
			_cyl(0.15, 0.11, 0.26, Vector3(0, 0.13, 0), pot, root)
			_cyl(0.035, 0.05, 0.55, Vector3(0, 0.52, 0), dwood, root)
			for i in 6:
				var ang := i * TAU / 6.0
				var fr: MeshInstance3D = office._box(Vector3(0.09, 0.02, 0.75),
					Vector3(cos(ang) * 0.28, 0.92, sin(ang) * 0.28), green, root, false)
				fr.rotation_degrees = Vector3(20, -rad_to_deg(ang) + 90.0, 0)
		"ficus":
			_cyl(0.17, 0.13, 0.30, Vector3(0, 0.15, 0), pm if params.has("col") else white, root)
			_cyl(0.03, 0.045, 0.60, Vector3(0, 0.58, 0), dwood, root)
			_sph(0.26, Vector3(0, 1.05, 0), green, root)
			_sph(0.20, Vector3(0.14, 1.25, 0.05), dgreen, root)
			_sph(0.16, Vector3(-0.15, 1.22, -0.05), green, root)
		"snake_plant":
			_cyl(0.13, 0.10, 0.22, Vector3(0, 0.11, 0), pm if params.has("col") else white, root)
			for i in 7:
				var ang := i * TAU / 7.0
				var bl2: MeshInstance3D = office._box(Vector3(0.06, 0.55 + (i % 3) * 0.12, 0.015),
					Vector3(cos(ang) * 0.06, 0.45, sin(ang) * 0.06),
					[green, dgreen][i % 2], root, false)
				bl2.rotation_degrees = Vector3(sin(ang) * 8.0, rad_to_deg(ang), cos(ang) * 8.0)
		"fern_hang":
			_cyl(0.008, 0.008, 0.45, Vector3(0, 0.23, 0), black, root)
			_cyl(0.14, 0.10, 0.14, Vector3(0, -0.02, 0), pot, root)
			for i in 8:
				var ang := i * TAU / 8.0
				var fd: MeshInstance3D = office._box(Vector3(0.05, 0.02, 0.42),
					Vector3(cos(ang) * 0.20, -0.12, sin(ang) * 0.20), green, root, false)
				fd.rotation_degrees = Vector3(38, -rad_to_deg(ang) + 90.0, 0)
		"bamboo":
			office._box(Vector3(0.34, 0.22, 0.34), Vector3(0, 0.11, 0),
				office._mat("sp_zen", Color(0.85, 0.82, 0.75)), root, false)
			for bp in [Vector3(-0.08, 0, 0.04), Vector3(0.02, 0, -0.06), Vector3(0.09, 0, 0.05)]:
				var bh: float = 0.9 + bp.x * 2.0
				_cyl(0.022, 0.022, bh, bp + Vector3(0, 0.2 + bh / 2.0, 0), green, root)
				var lf2: MeshInstance3D = office._box(Vector3(0.04, 0.015, 0.22),
					bp + Vector3(0.06, 0.3 + bh, 0), dgreen, root, false)
				lf2.rotation_degrees = Vector3(15, bp.z * 300.0, 0)
		"bigtree":
			_cyl(0.30, 0.24, 0.45, Vector3(0, 0.22, 0), pot, root)
			_cyl(0.06, 0.09, 1.1, Vector3(0, 0.95, 0), dwood, root)
			_sph(0.42, Vector3(0, 1.75, 0), green, root)
			_sph(0.32, Vector3(0.25, 2.0, 0.1), dgreen, root)
			_sph(0.28, Vector3(-0.25, 1.95, -0.1), green, root)
		"planter_long":
			office._box(Vector3(1.20, 0.35, 0.35), Vector3(0, 0.175, 0),
				office._mat("sp_planter", Color(0.45, 0.46, 0.48)), root, false)
			for i in 3:
				_sph(0.16, Vector3(-0.38 + i * 0.38, 0.45, 0), [green, dgreen, green][i], root)
		"bonsai":
			office._box(Vector3(0.30, 0.06, 0.20), Vector3(0, 0.03, 0),
				office._mat("sp_zen2", Color(0.35, 0.30, 0.28)), root, false)
			var tr2: MeshInstance3D = _cyl(0.02, 0.035, 0.20, Vector3(0.02, 0.15, 0), dwood, root)
			tr2.rotation_degrees = Vector3(0, 0, 18)
			var p1 := _sph(0.11, Vector3(-0.06, 0.28, 0), dgreen, root)
			p1.scale = Vector3(1.3, 0.5, 1.1)
			var p2 := _sph(0.08, Vector3(0.10, 0.22, 0.03), green, root)
			p2.scale = Vector3(1.2, 0.5, 1)
		"vase":
			_cyl(0.055, 0.075, 0.22, Vector3(0, 0.11, 0), white, root)
			for i in 5:
				var ang := i * TAU / 5.0
				var st2: MeshInstance3D = office._box(Vector3(0.008, 0.24, 0.008),
					Vector3(cos(ang) * 0.02, 0.30, sin(ang) * 0.02), green, root, false)
				st2.rotation_degrees = Vector3(sin(ang) * 14.0, 0, cos(ang) * 14.0)
				_sph(0.028, Vector3(cos(ang) * 0.07, 0.43, sin(ang) * 0.07), pm, root)
		"herbs":
			office._box(Vector3(0.50, 0.03, 0.18), Vector3(0, 0.015, 0), wood, root, false)
			for i in 3:
				_cyl(0.055, 0.045, 0.10, Vector3(-0.15 + i * 0.15, 0.08, 0), pot, root)
				_sph(0.06, Vector3(-0.15 + i * 0.15, 0.17, 0), [green, dgreen, green][i], root)
		"mosswall":
			office._box(Vector3(1.20, 0.80, 0.04), Vector3(0, 0.20, 0), dwood, root, false)
			office._box(Vector3(1.12, 0.72, 0.03), Vector3(0, 0.20, 0.015), dgreen, root, false)
			for i in 6:
				var mp := _sph(0.10, Vector3(-0.45 + (i % 3) * 0.45,
					0.02 + (i / 3) * 0.36, 0.035), [green, dgreen][i % 2], root)
				mp.scale = Vector3(1.4, 1.0, 0.3)
		"saguaro":
			_cyl(0.20, 0.16, 0.30, Vector3(0, 0.15, 0), pot, root)
			_cyl(0.09, 0.11, 1.3, Vector3(0, 0.95, 0), green, root)
			for aa in [[-1.0, 0.75], [1.0, 1.05]]:
				_cyl(0.05, 0.05, 0.25, Vector3(aa[0] * 0.17, aa[1], 0), green, root,
					Vector3(0, 0, aa[0] * 90.0))
				_cyl(0.05, 0.05, 0.30, Vector3(aa[0] * 0.28, aa[1] + 0.17, 0), green, root)
		"pampas":
			_cyl(0.06, 0.09, 0.35, Vector3(0, 0.175, 0),
				office._mat("sp_zen", Color(0.85, 0.82, 0.75)), root)
			for i in 5:
				var ang := i * TAU / 5.0
				var pst: MeshInstance3D = office._box(Vector3(0.008, 0.6, 0.008),
					Vector3(cos(ang) * 0.03, 0.6, sin(ang) * 0.03),
					office._mat("sp_dry", Color(0.75, 0.65, 0.48)), root, false)
				pst.rotation_degrees = Vector3(sin(ang) * 10.0, 0, cos(ang) * 10.0)
				var pl2 := _sph(0.05, Vector3(cos(ang) * 0.12, 0.95, sin(ang) * 0.12),
					office._mat("sp_plume", Color(0.88, 0.80, 0.68)), root)
				pl2.scale = Vector3(1, 2.2, 1)
		"pothos":
			_cyl(0.07, 0.055, 0.12, Vector3(0, 0.06, 0), white, root)
			_sph(0.09, Vector3(0, 0.14, 0), green, root)
			for i in 3:
				var vn: MeshInstance3D = office._box(Vector3(0.03, 0.30, 0.015),
					Vector3(-0.08 + i * 0.08, -0.02, 0.08), dgreen, root, false)
				vn.rotation_degrees = Vector3(24, i * 40.0 - 40.0, 0)
		# ------------------------------------------------- wall pieces
		"slatwall":
			var sw := float(params.get("w", 2.0))
			office._box(Vector3(sw, 0.06, 0.10), Vector3(0, 0.03, 0), dwood, root, false)
			office._box(Vector3(sw, 0.06, 0.10), Vector3(0, 2.30, 0), dwood, root, false)
			var nslat := maxi(int(sw / 0.155), 3)
			for i in nslat:
				office._box(Vector3(0.07, 2.25, 0.05),
					Vector3(-sw / 2.0 + 0.07 + i * (sw - 0.14) / maxf(nslat - 1, 1), 1.16, 0),
					pm, root, false)
			root.set_meta("half_len", sw / 2.0)
		"glassframe":
			var gw := float(params.get("w", 2.0))
			office._box(Vector3(gw, 0.06, 0.07), Vector3(0, 0.03, 0), black, root, false)
			office._box(Vector3(gw, 0.06, 0.07), Vector3(0, 2.42, 0), black, root, false)
			for fx2 in [-gw / 2.0 + 0.03, gw / 2.0 - 0.03]:
				office._box(Vector3(0.06, 2.45, 0.07), Vector3(fx2, 1.22, 0), black, root, false)
			var mn := int(gw / 0.5)
			for i in mn - 1:
				office._box(Vector3(0.035, 2.36, 0.05),
					Vector3(-gw / 2.0 + (i + 1) * gw / mn, 1.22, 0), black, root, false)
			office._box(Vector3(gw - 0.08, 0.035, 0.05), Vector3(0, 1.0, 0), black, root, false)
			office._box(Vector3(gw - 0.08, 2.30, 0.02), Vector3(0, 1.22, 0), _glass_mat(), root, false)
		"column_p":
			_cyl(0.16, 0.18, 2.55, Vector3(0, 1.275, 0), pm, root)
			_cyl(0.21, 0.21, 0.08, Vector3(0, 0.04, 0), pm, root)
			_cyl(0.21, 0.21, 0.08, Vector3(0, 2.51, 0), pm, root)
		"fence":
			var fw := float(params.get("w", 1.8))
			for rz2 in [0.30, 0.75]:
				office._box(Vector3(fw, 0.05, 0.04), Vector3(0, rz2, 0), pm, root, false)
			var npk := maxi(int(fw / 0.40) + 1, 3)
			for i in npk:
				office._box(Vector3(0.05, 0.90, 0.05),
					Vector3(-fw / 2.0 + 0.05 + i * (fw - 0.10) / maxf(npk - 1, 1), 0.45, 0),
					pm, root, false)
			root.set_meta("half_len", fw / 2.0)
		# ----------------------------------------------- gadgets & tech
		"dual_mon":
			office._box(Vector3(0.22, 0.03, 0.16), Vector3(0, 0.015, 0), black, root, false)
			_cyl(0.025, 0.025, 0.32, Vector3(0, 0.18, -0.03), black, root)
			for mx in [[-0.26, 14.0], [0.26, -14.0]]:
				var mo: MeshInstance3D = office._box(Vector3(0.50, 0.30, 0.02),
					Vector3(mx[0], 0.34, 0), _emat(Color(0.16, 0.28, 0.42), 0.7), root, false)
				mo.rotation_degrees = Vector3(0, mx[1], 0)
		"monitor_uw":
			office._box(Vector3(0.26, 0.03, 0.18), Vector3(0, 0.015, 0), black, root, false)
			_cyl(0.03, 0.03, 0.22, Vector3(0, 0.13, -0.04), black, root)
			office._box(Vector3(0.88, 0.36, 0.025), Vector3(0, 0.42, 0),
				_emat(Color(0.20, 0.32, 0.30), 0.8), root, false)
			for wx2 in [[-0.42, 18.0], [0.42, -18.0]]:
				var uw: MeshInstance3D = office._box(Vector3(0.16, 0.36, 0.025),
					Vector3(wx2[0], 0.42, 0.03), _emat(Color(0.20, 0.32, 0.30), 0.8), root, false)
				uw.rotation_degrees = Vector3(0, wx2[1], 0)
		"aio":
			office._box(Vector3(0.30, 0.02, 0.18), Vector3(0, 0.01, 0), white, root, false)
			var an: MeshInstance3D = office._box(Vector3(0.05, 0.20, 0.02),
				Vector3(0, 0.12, -0.04), white, root, false)
			an.rotation_degrees = Vector3(-12, 0, 0)
			office._box(Vector3(0.62, 0.40, 0.03), Vector3(0, 0.42, 0), white, root, false)
			office._box(Vector3(0.58, 0.32, 0.01), Vector3(0, 0.45, 0.016),
				_emat(Color(0.25, 0.38, 0.52), 0.8), root, false)
		"pc_rgb":
			office._box(Vector3(0.24, 0.48, 0.46), Vector3(0, 0.26, 0), black, root, false)
			office._box(Vector3(0.01, 0.42, 0.40), Vector3(0.125, 0.26, 0),
				_glass_mat(Color(0.5, 0.6, 0.7, 0.25)), root, false)
			var rgbc := [Color(1.0, 0.3, 0.5), Color(0.3, 0.8, 1.0), Color(0.6, 0.4, 1.0)]
			for i in 3:
				var fan: MeshInstance3D = _cyl(0.055, 0.055, 0.02,
					Vector3(0.11, 0.12 + i * 0.14, -0.12), _emat(rgbc[i], 1.8), root,
					Vector3(0, 0, 90))
				fan.scale = Vector3(1, 0.5, 1)
			_omni(Vector3(0.2, 0.3, 0), Color(0.6, 0.5, 1.0), 0.5, 1.2, root)
		"laptop_stand":
			var lst: MeshInstance3D = office._box(Vector3(0.28, 0.015, 0.24),
				Vector3(0, 0.10, 0), metal, root, false)
			lst.rotation_degrees = Vector3(-16, 0, 0)
			for slx in [-0.12, 0.12]:
				var sll: MeshInstance3D = office._box(Vector3(0.02, 0.13, 0.02),
					Vector3(slx, 0.05, 0.06), metal, root, false)
				sll.rotation_degrees = Vector3(20, 0, 0)
			var lsc: MeshInstance3D = office._box(Vector3(0.26, 0.17, 0.008),
				Vector3(0, 0.20, -0.09), _emat(Color(0.22, 0.32, 0.42), 0.7), root, false)
			lsc.rotation_degrees = Vector3(-8, 0, 0)
			var lkb: MeshInstance3D = office._box(Vector3(0.26, 0.008, 0.17),
				Vector3(0, 0.125, 0.02), office._mat("sp_alu", Color(0.75, 0.76, 0.78)), root, false)
			lkb.rotation_degrees = Vector3(-16, 0, 0)
		"kb_rgb":
			office._box(Vector3(0.36, 0.025, 0.13), Vector3(0, 0.015, 0), black, root, false)
			office._box(Vector3(0.34, 0.008, 0.11), Vector3(0, 0.03, 0),
				office._mat("sp_keys", Color(0.28, 0.29, 0.32)), root, false)
			office._box(Vector3(0.37, 0.006, 0.14), Vector3(0, 0.006, 0),
				_emat(Color.html(pchex) if params.has("col") else Color(0.5, 0.3, 1.0), 1.6), root, false)
			_omni(Vector3(0, 0.05, 0.1), Color(0.55, 0.35, 1.0), 0.35, 0.7, root)
		"mouse_pad":
			office._box(Vector3(0.42, 0.005, 0.32), Vector3(0, 0.003, 0),
				office._mat("sp_deskmat", Color(0.16, 0.17, 0.20)), root, false)
			var ms := _sph(0.035, Vector3(0.08, 0.02, 0.02), black, root)
			ms.scale = Vector3(0.85, 0.6, 1.3)
		"mic":
			_cyl(0.07, 0.09, 0.025, Vector3(0, 0.012, 0), black, root)
			var ma1: MeshInstance3D = office._box(Vector3(0.02, 0.30, 0.02),
				Vector3(0, 0.15, 0.03), black, root, false)
			ma1.rotation_degrees = Vector3(14, 0, 0)
			var ma2: MeshInstance3D = office._box(Vector3(0.02, 0.24, 0.02),
				Vector3(0, 0.37, -0.03), black, root, false)
			ma2.rotation_degrees = Vector3(-38, 0, 0)
			var mcap: MeshInstance3D = _cyl(0.045, 0.045, 0.12, Vector3(0, 0.46, 0.08),
				office._mat("sp_micbody", Color(0.22, 0.23, 0.26)), root, Vector3(0, 0, 90))
			mcap.rotation_degrees = Vector3(90, 0, 0)
			_cyl(0.05, 0.05, 0.005, Vector3(0, 0.46, 0.16), black, root, Vector3(90, 0, 0))
		"headphone_stand":
			_cyl(0.07, 0.09, 0.02, Vector3(0, 0.01, 0), metal, root)
			_cyl(0.015, 0.015, 0.26, Vector3(0, 0.15, 0), metal, root)
			office._box(Vector3(0.16, 0.03, 0.05), Vector3(0, 0.29, 0), metal, root, false)
			var hb := _sph(0.09, Vector3(0, 0.26, 0), black, root)
			hb.scale = Vector3(1, 0.55, 1)
			for hx2 in [-0.085, 0.085]:
				var cup := _sph(0.045, Vector3(hx2, 0.19, 0), black, root)
				cup.scale = Vector3(0.6, 1, 1)
		"webcam":
			for i in 3:
				var ang := i * TAU / 3.0
				var wl: MeshInstance3D = _cyl(0.008, 0.008, 0.14,
					Vector3(cos(ang) * 0.05, 0.07, sin(ang) * 0.05), black, root)
				wl.rotation_degrees = Vector3(sin(ang) * 20.0, 0, cos(ang) * -20.0)
			office._box(Vector3(0.09, 0.06, 0.05), Vector3(0, 0.17, 0), black, root, false)
			_cyl(0.018, 0.018, 0.01, Vector3(0, 0.17, 0.028), _emat(Color(0.2, 0.5, 0.9), 0.8),
				root, Vector3(90, 0, 0))
			_sph(0.006, Vector3(0.03, 0.19, 0.026), _emat(Color(0.3, 0.9, 0.4), 2.0), root)
		"streamdeck":
			var sd: MeshInstance3D = office._box(Vector3(0.13, 0.09, 0.02),
				Vector3(0, 0.05, 0), black, root, false)
			sd.rotation_degrees = Vector3(-30, 0, 0)
			var sdc := [Color(0.9, 0.4, 0.4), Color(0.4, 0.8, 0.5), Color(0.4, 0.55, 0.95),
				Color(0.95, 0.75, 0.3), Color(0.7, 0.45, 0.9), Color(0.35, 0.8, 0.8)]
			for i in 6:
				var kx := -0.035 + (i % 3) * 0.035
				var ky := 0.055 + (i / 3) * 0.032
				var sk: MeshInstance3D = office._box(Vector3(0.026, 0.026, 0.005),
					Vector3(kx, ky, 0.014 - (i / 3) * 0.018), _emat(sdc[i], 1.2), root, false)
				sk.rotation_degrees = Vector3(-30, 0, 0)
		"pen_tablet":
			office._box(Vector3(0.34, 0.012, 0.24), Vector3(0, 0.006, 0), black, root, false)
			office._box(Vector3(0.26, 0.004, 0.17), Vector3(0.02, 0.014, 0),
				office._mat("sp_keys", Color(0.28, 0.29, 0.32)), root, false)
			var pen: MeshInstance3D = _cyl(0.006, 0.008, 0.15, Vector3(-0.20, 0.02, 0.04),
				black, root, Vector3(0, 0, 78))
			pen.rotation_degrees = Vector3(0, 25, 90)
		"printer3d":
			for cpx in [-0.18, 0.18]:
				office._box(Vector3(0.04, 0.42, 0.04), Vector3(cpx, 0.21, -0.14), black, root, false)
			office._box(Vector3(0.44, 0.05, 0.05), Vector3(0, 0.44, -0.14), black, root, false)
			office._box(Vector3(0.40, 0.03, 0.34), Vector3(0, 0.015, 0), black, root, false)
			office._box(Vector3(0.30, 0.015, 0.24), Vector3(0, 0.04, 0.01), metal, root, false)
			_sph(0.035, Vector3(0, 0.075, 0.01), _emat(Color(0.95, 0.55, 0.25), 1.0), root)
			office._box(Vector3(0.05, 0.08, 0.05), Vector3(0, 0.38, -0.02), metal, root, false)
		"projector":
			office._box(Vector3(0.30, 0.10, 0.24), Vector3(0, 0.06, 0), white, root, false)
			_cyl(0.035, 0.04, 0.03, Vector3(-0.07, 0.07, 0.13),
				_emat(Color(0.85, 0.90, 1.0), 1.2), root, Vector3(90, 0, 0))
			_cyl(0.02, 0.02, 0.008, Vector3(0.08, 0.115, 0.04), black, root)
		"proj_screen":
			for slx2 in [-0.5, 0.5]:
				for sa in [22.0, -22.0]:
					var psl: MeshInstance3D = office._box(Vector3(0.035, 0.5, 0.035),
						Vector3(slx2, 0.12, 0), black, root, false)
					psl.rotation_degrees = Vector3(sa, 0, 0)
			_cyl(0.04, 0.04, 1.4, Vector3(0, 0.26, 0), black, root, Vector3(0, 0, 90))
			office._box(Vector3(1.30, 1.35, 0.02), Vector3(0, 1.02, 0),
				_emat(Color(0.96, 0.96, 0.94), 0.35), root, false)
			office._box(Vector3(1.34, 0.05, 0.04), Vector3(0, 1.72, 0), black, root, false)
		"router":
			office._box(Vector3(0.26, 0.05, 0.18), Vector3(0, 0.03, 0), black, root, false)
			for ax in [-0.09, 0.0, 0.09]:
				var ant: MeshInstance3D = office._box(Vector3(0.015, 0.16, 0.015),
					Vector3(ax, 0.13, -0.07), black, root, false)
				ant.rotation_degrees = Vector3(-14, 0, ax * 100.0)
			for i in 3:
				_sph(0.006, Vector3(-0.06 + i * 0.06, 0.058, 0.09),
					_emat(Color(0.3, 0.9, 0.4), 2.0), root)
		"charging_dock":
			office._box(Vector3(0.26, 0.03, 0.12), Vector3(0, 0.015, 0), white, root, false)
			for phx in [[-0.06, "26272b"], [0.06, "3a4a6b"]]:
				var ph: MeshInstance3D = office._box(Vector3(0.075, 0.15, 0.008),
					Vector3(phx[0], 0.10, -0.01),
					office._mat("sp_ph_" + str(phx[1]), Color.html(str(phx[1]))), root, false)
				ph.rotation_degrees = Vector3(-12, 0, 0)
			_sph(0.005, Vector3(0.11, 0.035, 0.05), _emat(Color(0.3, 0.9, 0.4), 2.0), root)
		"console":
			var cs: MeshInstance3D = office._box(Vector3(0.09, 0.30, 0.26),
				Vector3(0, 0.16, 0), white, root, false)
			cs.rotation_degrees = Vector3(0, 0, -4)
			office._box(Vector3(0.02, 0.28, 0.24), Vector3(-0.055, 0.16, 0), black, root, false)
			for cx2 in [0.12, 0.22]:
				var pad := _sph(0.035, Vector3(cx2, 0.025, 0.08), black, root)
				pad.scale = Vector3(1.4, 0.5, 1)
			_sph(0.005, Vector3(0.035, 0.29, 0.09), _emat(Color(0.35, 0.65, 1.0), 2.0), root)
		"boombox":
			office._box(Vector3(0.42, 0.20, 0.14), Vector3(0, 0.11, 0),
				office._mat("sp_boom", Color(0.85, 0.83, 0.78)), root, false)
			for bxp in [-0.13, 0.13]:
				_cyl(0.065, 0.065, 0.01, Vector3(bxp, 0.11, 0.072), black, root, Vector3(90, 0, 0))
				_cyl(0.03, 0.03, 0.012, Vector3(bxp, 0.11, 0.074),
					office._mat("sp_alu", Color(0.75, 0.76, 0.78)), root, Vector3(90, 0, 0))
			office._box(Vector3(0.10, 0.05, 0.10), Vector3(0, 0.235, 0),
				office._mat("sp_boom", Color(0.85, 0.83, 0.78)), root, false)
			office._box(Vector3(0.08, 0.025, 0.005), Vector3(0, 0.13, 0.073),
				_emat(Color(0.3, 0.8, 0.9), 0.9), root, false)
		# --------------------------------------------------- decor pack
		"rug_col":
			_cyl(0.72, 0.72, 0.015, Vector3(0, 0.008, 0), pm, root)
			_cyl(0.52, 0.52, 0.008, Vector3(0, 0.02, 0),
				office._mat("sp_c2_" + pchex, Color.html(pchex).lightened(0.18)), root)
		"curtain":
			_cyl(0.02, 0.02, 1.7, Vector3(0, 2.32, 0), metal, root, Vector3(0, 0, 90))
			for cpx in [-0.55, 0.55]:
				office._box(Vector3(0.55, 2.25, 0.05), Vector3(cpx, 1.18, 0), pm, root, false)
				for fw in 3:
					office._box(Vector3(0.06, 2.25, 0.06),
						Vector3(cpx - 0.18 + fw * 0.18, 1.18, 0.01), pm, root, false)
		"mirror_stand":
			var mfr: MeshInstance3D = office._box(Vector3(0.58, 1.75, 0.045),
				Vector3(0, 0.87, -0.02), wood, root, false)
			mfr.rotation_degrees = Vector3(-6, 0, 0)
			var mgl: MeshInstance3D = office._box(Vector3(0.48, 1.62, 0.01),
				Vector3(0, 0.87, 0.012), office._mat("sp_mirror", Color(0.72, 0.80, 0.84)), root, false)
			mgl.rotation_degrees = Vector3(-6, 0, 0)
		"mirror_round":
			_cyl(0.24, 0.24, 0.03, Vector3(0, 0.1, 0),
				office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root, Vector3(90, 0, 0))
			_cyl(0.21, 0.21, 0.015, Vector3(0, 0.1, 0.012),
				office._mat("sp_mirror", Color(0.72, 0.80, 0.84)), root, Vector3(90, 0, 0))
		"art_canvas":
			office._box(Vector3(0.62, 0.82, 0.025), Vector3(0, 0.1, 0), white, root, false)
			office._box(Vector3(0.56, 0.76, 0.01), Vector3(0, 0.1, 0.012), pm, root, false)
			_cyl(0.12, 0.12, 0.008, Vector3(-0.08, 0.2, 0.02), white, root, Vector3(90, 0, 0))
			office._box(Vector3(0.30, 0.025, 0.006), Vector3(0.05, -0.12, 0.02),
				office._mat("sp_c2_" + pchex, Color.html(pchex).darkened(0.3)), root, false)
		"sculpture":
			office._box(Vector3(0.30, 0.65, 0.30), Vector3(0, 0.32, 0), white, root, false)
			var scb := [[0.14, 0.72, 0.0], [0.11, 0.86, 25.0], [0.08, 0.98, 50.0]]
			for sc in scb:
				var cube: MeshInstance3D = office._box(Vector3(sc[0], sc[0], sc[0]),
					Vector3(0, sc[1], 0), pm, root, false)
				cube.rotation_degrees = Vector3(0, sc[2], 15)
		"bookends":
			for bx in [-0.14, 0.14]:
				office._box(Vector3(0.015, 0.14, 0.10), Vector3(bx, 0.07, 0), black, root, false)
				office._box(Vector3(0.05, 0.015, 0.10), Vector3(bx * 0.82, 0.008, 0), black, root, false)
			var bkc := [Color(0.42, 0.52, 0.65), Color(0.80, 0.51, 0.40), Color(0.62, 0.67, 0.57),
				Color(0.85, 0.78, 0.55), Color(0.35, 0.35, 0.40)]
			for i in 5:
				office._box(Vector3(0.035, 0.13 - (i % 2) * 0.015, 0.09),
					Vector3(-0.09 + i * 0.045, 0.068, 0),
					office._mat("sp_bk%d" % i, bkc[i]), root, false)
		"diffuser":
			_cyl(0.035, 0.045, 0.10, Vector3(0, 0.05, 0), white, root)
			for i in 3:
				var stick: MeshInstance3D = office._box(Vector3(0.005, 0.18, 0.005),
					Vector3(0, 0.17, 0), dwood, root, false)
				stick.rotation_degrees = Vector3(i * 10.0 - 10.0, 0, i * 12.0 - 12.0)
		"vase_floor":
			_cyl(0.10, 0.16, 0.65, Vector3(0, 0.32, 0), pm, root)
			for i in 3:
				var br: MeshInstance3D = office._box(Vector3(0.012, 0.75, 0.012),
					Vector3(0, 0.95, 0), dwood, root, false)
				br.rotation_degrees = Vector3(i * 8.0 - 8.0, i * 60.0, 6.0)
		"banner":
			_cyl(0.006, 0.006, 1.6, Vector3(0, 0.25, 0), black, root, Vector3(0, 0, 90))
			var bnc := [Color(0.85, 0.45, 0.40), Color(0.95, 0.78, 0.35), Color(0.45, 0.65, 0.55),
				Color(0.45, 0.55, 0.80), Color(0.85, 0.60, 0.70), Color(0.60, 0.70, 0.60)]
			for i in 6:
				var fl2: MeshInstance3D = office._box(Vector3(0.10, 0.13, 0.008),
					Vector3(-0.62 + i * 0.25, 0.16, 0), office._mat("sp_fl%d" % i, bnc[i]), root, false)
				fl2.rotation_degrees = Vector3(0, 0, 45)
		"photo_wall":
			var pwp := [[Vector3(-0.30, 0.22, 0), 0.22, 0.28], [Vector3(0.10, 0.28, 0), 0.30, 0.22],
				[Vector3(-0.22, -0.16, 0), 0.26, 0.20], [Vector3(0.20, -0.12, 0), 0.20, 0.26]]
			for i in pwp.size():
				var pw: Array = pwp[i]
				office._box(Vector3(pw[1], pw[2], 0.02), pw[0], [black, wood][i % 2], root, false)
				office._box(Vector3(pw[1] - 0.05, pw[2] - 0.05, 0.008),
					pw[0] + Vector3(0, 0, 0.012), white, root, false)
		"awards":
			office._box(Vector3(0.80, 0.55, 0.03), Vector3(0, 0.1, 0), dwood, root, false)
			for i in 3:
				_cyl(0.07, 0.07, 0.015, Vector3(-0.22 + i * 0.22, 0.16, 0.02),
					_emat(Color(0.95, 0.78, 0.30), 0.5), root, Vector3(90, 0, 0))
				office._box(Vector3(0.10, 0.04, 0.008), Vector3(-0.22 + i * 0.22, -0.04, 0.02),
					office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root, false)
		"plant_stand":
			var tiers := [[0.35, -0.18], [0.62, 0.0], [0.90, 0.18]]
			for t2 in tiers:
				office._box(Vector3(0.24, 0.025, 0.24), Vector3(t2[1], t2[0], 0), wood, root, false)
				office._box(Vector3(0.04, t2[0], 0.04), Vector3(t2[1], t2[0] / 2.0, 0.09), wood, root, false)
				office._box(Vector3(0.04, t2[0], 0.04), Vector3(t2[1], t2[0] / 2.0, -0.09), wood, root, false)
				_cyl(0.06, 0.05, 0.09, Vector3(t2[1], t2[0] + 0.06, 0), pot, root)
				_sph(0.07, Vector3(t2[1], t2[0] + 0.15, 0), [green, dgreen, green][int(t2[0] * 3) % 3], root)
		# -------------------------------------------------- office pack
		"reception":
			office._box(Vector3(1.90, 1.10, 0.10), Vector3(0, 0.55, 0.30), white, root, false)
			office._box(Vector3(2.00, 0.06, 0.35), Vector3(0, 1.13, 0.22), wood, root, false)
			office._box(Vector3(1.70, 0.05, 0.60), Vector3(0, 0.72, -0.15), white, root, false)
			for lx in [-0.80, 0.80]:
				office._box(Vector3(0.06, 0.70, 0.55), Vector3(lx, 0.36, -0.15), white, root, false)
			_cyl(0.09, 0.09, 0.015, Vector3(0, 0.62, 0.36), _emat(Color(1.0, 0.78, 0.32), 0.9),
				root, Vector3(90, 0, 0))
		"podium":
			office._box(Vector3(0.55, 1.10, 0.40), Vector3(0, 0.55, 0), dwood, root, false)
			var ptop: MeshInstance3D = office._box(Vector3(0.60, 0.04, 0.45),
				Vector3(0, 1.13, -0.02), dwood, root, false)
			ptop.rotation_degrees = Vector3(-12, 0, 0)
			_cyl(0.008, 0.008, 0.25, Vector3(0.15, 1.28, -0.05), black, root, Vector3(-20, 0, 0))
			_sph(0.02, Vector3(0.15, 1.40, -0.09), black, root)
		"riser":
			office._box(Vector3(2.40, 0.24, 1.60), Vector3(0, 0.12, 0), dwood, root, false)
			office._box(Vector3(2.44, 0.04, 1.64), Vector3(0, 0.26, 0), wood, root, false)
		"flipchart":
			for i in 3:
				var ang := i * TAU / 3.0
				var fcl: MeshInstance3D = _cyl(0.02, 0.02, 1.7,
					Vector3(cos(ang) * 0.3, 0.8, sin(ang) * 0.3 - 0.1), metal, root)
				fcl.rotation_degrees = Vector3(sin(ang) * 18.0, 0, cos(ang) * -18.0)
			office._box(Vector3(0.72, 0.95, 0.03), Vector3(0, 1.35, 0.08), white, root, false)
			office._box(Vector3(0.66, 0.88, 0.01), Vector3(0, 1.34, 0.10),
				office._mat("sp_paper", Color(0.98, 0.98, 0.96)), root, false)
			var curl: MeshInstance3D = office._box(Vector3(0.66, 0.20, 0.01),
				Vector3(0, 1.86, 0.16), office._mat("sp_paper", Color(0.98, 0.98, 0.96)), root, false)
			curl.rotation_degrees = Vector3(55, 0, 0)
			office._box(Vector3(0.30, 0.02, 0.005), Vector3(-0.1, 1.5, 0.11), black, root, false)
			office._box(Vector3(0.22, 0.02, 0.005), Vector3(0.05, 1.38, 0.11),
				office._mat("sp_tapred", Color(0.85, 0.25, 0.25)), root, false)
		"projcart":
			for px in [-0.28, 0.28]:
				for pz in [-0.20, 0.20]:
					_cyl(0.015, 0.015, 0.75, Vector3(px, 0.42, pz), black, root)
					_sph(0.03, Vector3(px, 0.03, pz), black, root)
			for sh in [0.18, 0.50, 0.80]:
				office._box(Vector3(0.64, 0.03, 0.46), Vector3(0, sh, 0), black, root, false)
			office._box(Vector3(0.28, 0.09, 0.22), Vector3(0, 0.86, 0), white, root, false)
			_cyl(0.03, 0.035, 0.02, Vector3(-0.06, 0.87, 0.12),
				_emat(Color(0.85, 0.90, 1.0), 1.0), root, Vector3(90, 0, 0))
		"cubpanel":
			office._box(Vector3(1.50, 1.50, 0.06), Vector3(0, 0.80, 0), pm, root, false)
			office._box(Vector3(1.54, 0.05, 0.08), Vector3(0, 1.57, 0), metal, root, false)
			for fx in [-0.60, 0.60]:
				office._box(Vector3(0.10, 0.05, 0.30), Vector3(fx, 0.03, 0), metal, root, false)
		"mailslots":
			office._box(Vector3(0.90, 0.95, 0.30), Vector3(0, 0.85, 0), wood, root, false)
			for r3 in 3:
				for c3 in 3:
					office._box(Vector3(0.24, 0.24, 0.02),
						Vector3(-0.28 + c3 * 0.28, 0.55 + r3 * 0.28, 0.155), white, root, false)
			office._box(Vector3(0.90, 0.38, 0.30), Vector3(0, 0.19, 0), wood, root, false)
		"firstaid":
			office._box(Vector3(0.32, 0.32, 0.10), Vector3(0, 0.1, 0), white, root, false)
			office._box(Vector3(0.18, 0.05, 0.012), Vector3(0, 0.1, 0.052),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root, false)
			office._box(Vector3(0.05, 0.18, 0.012), Vector3(0, 0.1, 0.052),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root, false)
		"fireext":
			_cyl(0.07, 0.07, 0.45, Vector3(0, 0.28, 0),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root)
			_cyl(0.02, 0.02, 0.06, Vector3(0, 0.54, 0), black, root)
			office._box(Vector3(0.03, 0.03, 0.12), Vector3(0, 0.58, 0.03), black, root, false)
			var hose: MeshInstance3D = office._box(Vector3(0.02, 0.28, 0.02),
				Vector3(0.07, 0.38, 0.02), black, root, false)
			hose.rotation_degrees = Vector3(0, 0, -18)
		"exitsign":
			office._box(Vector3(0.42, 0.16, 0.06), Vector3(0, 0.1, 0),
				_emat(Color(0.20, 0.70, 0.35), 1.6), root, false)
			office._box(Vector3(0.30, 0.05, 0.012), Vector3(0, 0.1, 0.032), white, root, false)
			_omni(Vector3(0, 0.05, 0.2), Color(0.3, 0.9, 0.5), 0.4, 1.2, root)
		"acoustic":
			for i in 4:
				var aq: MeshInstance3D = office._box(Vector3(0.30, 0.30, 0.05),
					Vector3(-0.24 + (i % 2) * 0.48, -0.24 + (i / 2) * 0.48, 0), pm, root, false)
				aq.rotation_degrees = Vector3(0, 0, 45)
		"rollup":
			_cyl(0.05, 0.05, 0.75, Vector3(0, 0.05, 0), metal, root, Vector3(0, 0, 90))
			office._box(Vector3(0.70, 1.85, 0.02), Vector3(0, 1.0, 0), pm, root, false)
			_cyl(0.16, 0.16, 0.01, Vector3(0, 1.45, 0.015), white, root, Vector3(90, 0, 0))
			office._box(Vector3(0.40, 0.04, 0.008), Vector3(0, 1.05, 0.015), white, root, false)
			office._box(Vector3(0.30, 0.04, 0.008), Vector3(0, 0.95, 0.015), white, root, false)
		"badgegate":
			for gx in [-0.45, 0.45]:
				office._box(Vector3(0.18, 1.05, 0.90), Vector3(gx, 0.53, 0), white, root, false)
				office._box(Vector3(0.18, 0.03, 0.90), Vector3(gx, 1.06, 0), black, root, false)
				_sph(0.012, Vector3(gx - signf(gx) * 0.092, 0.95, 0.3),
					_emat(Color(0.3, 0.9, 0.4), 2.0), root)
			for gx2 in [-0.18, 0.18]:
				var flap: MeshInstance3D = office._box(Vector3(0.20, 0.35, 0.02),
					Vector3(gx2, 0.75, 0), _glass_mat(), root, false)
				flap.rotation_degrees = Vector3(0, signf(gx2) * 20.0, 0)
		"cctv":
			office._box(Vector3(0.05, 0.05, 0.16), Vector3(0, 0.05, 0.05), white, root, false)
			var camb: MeshInstance3D = office._box(Vector3(0.10, 0.09, 0.22),
				Vector3(0, 0.0, 0.18), white, root, false)
			camb.rotation_degrees = Vector3(-18, 0, 0)
			_cyl(0.035, 0.035, 0.02, Vector3(0, -0.045, 0.29), black, root, Vector3(72, 0, 0))
			_sph(0.006, Vector3(0.03, 0.045, 0.09), _emat(Color(0.9, 0.2, 0.2), 2.4), root)
		"suggest":
			office._box(Vector3(0.10, 0.85, 0.10), Vector3(0, 0.42, 0), metal, root, false)
			office._box(Vector3(0.34, 0.28, 0.24), Vector3(0, 1.0, 0), wood, root, false)
			office._box(Vector3(0.20, 0.015, 0.03), Vector3(0, 1.145, 0), black, root, false)
			office._box(Vector3(0.20, 0.08, 0.005), Vector3(0, 0.98, 0.122), white, root, false)
		"timeclock":
			office._box(Vector3(0.30, 0.38, 0.12), Vector3(0, 0.1, 0),
				office._mat("sp_safe", Color(0.25, 0.27, 0.32)), root, false)
			_cyl(0.09, 0.09, 0.015, Vector3(0, 0.17, 0.062), white, root, Vector3(90, 0, 0))
			office._box(Vector3(0.008, 0.06, 0.005), Vector3(0, 0.19, 0.072), black, root, false)
			office._box(Vector3(0.10, 0.015, 0.06), Vector3(0, -0.02, 0.07), black, root, false)
			office._box(Vector3(0.24, 0.18, 0.04), Vector3(0.0, -0.30, 0.01), wood, root, false)
			for i in 4:
				office._box(Vector3(0.045, 0.14, 0.008), Vector3(-0.08 + i * 0.055, -0.28, 0.035),
					white, root, false)
		"deskdivider":
			office._box(Vector3(0.80, 0.35, 0.02), Vector3(0, 0.20, 0),
				_glass_mat(Color(0.85, 0.88, 0.90, 0.4)), root, false)
			for cx in [-0.30, 0.30]:
				office._box(Vector3(0.06, 0.03, 0.06), Vector3(cx, 0.015, 0), metal, root, false)
		"deskphone":
			var phb: MeshInstance3D = office._box(Vector3(0.20, 0.05, 0.16),
				Vector3(0, 0.03, 0), black, root, false)
			phb.rotation_degrees = Vector3(-8, 0, 0)
			for i in 9:
				office._box(Vector3(0.02, 0.008, 0.02),
					Vector3(0.02 + (i % 3) * 0.03, 0.062, -0.02 + (i / 3) * 0.03),
					white, root, false)
			var hs: MeshInstance3D = office._box(Vector3(0.05, 0.03, 0.18),
				Vector3(-0.065, 0.08, 0), black, root, false)
			hs.rotation_degrees = Vector3(-8, 0, 0)
		# -------------------------------------------------- scandi pack
		"string_shelf":
			for sx in [-0.40, 0.40]:
				office._box(Vector3(0.015, 0.80, 0.24), Vector3(sx, 0.42, 0), white, root, false)
			for sh in 3:
				office._box(Vector3(0.80, 0.02, 0.22), Vector3(0, 0.12 + sh * 0.30, 0), white, root, false)
			office._box(Vector3(0.10, 0.14, 0.12), Vector3(-0.2, 0.44, 0), white, root, false)
			_sph(0.05, Vector3(0.2, 0.78, 0), green, root)
		"daybed":
			office._box(Vector3(1.90, 0.12, 0.85), Vector3(0, 0.28, 0), ply, root, false)
			office._box(Vector3(1.85, 0.14, 0.80), Vector3(0, 0.42, 0), white, root, false)
			for lx in [-0.85, 0.85]:
				for lz in [-0.32, 0.32]:
					_cyl(0.02, 0.025, 0.24, Vector3(lx, 0.11, lz), wood, root)
			office._box(Vector3(0.45, 0.10, 0.32), Vector3(-0.65, 0.54, -0.15),
				office._mat("sp_c_9eab91", Color.html("9eab91")), root, false)
			office._box(Vector3(0.60, 0.05, 0.75), Vector3(0.45, 0.51, 0),
				office._mat("sp_c_b3705c", Color.html("b3705c")), root, false)
		"hairpin":
			_cyl(0.28, 0.28, 0.035, Vector3(0, 0.45, 0), ply, root)
			for i in 3:
				var ang := i * TAU / 3.0
				for spread in [-0.05, 0.05]:
					var hp: MeshInstance3D = _cyl(0.008, 0.008, 0.47,
						Vector3(cos(ang) * (0.20 + spread), 0.22, sin(ang) * (0.20 + spread)),
						black, root)
					hp.rotation_degrees = Vector3(sin(ang) * (10.0 + spread * 100.0), 0,
						cos(ang) * -(10.0 + spread * 100.0))
		"cubeside":
			office._box(Vector3(0.45, 0.045, 0.45), Vector3(0, 0.42, 0), pm, root, false)
			for lx in [-0.19, 0.19]:
				for lz in [-0.19, 0.19]:
					office._box(Vector3(0.055, 0.42, 0.055), Vector3(lx, 0.21, lz), pm, root, false)
		"kallax":
			for r4 in 3:
				office._box(Vector3(0.82, 0.03, 0.38), Vector3(0, 0.02 + r4 * 0.38, 0), pm, root, false)
			for c4 in 3:
				office._box(Vector3(0.03, 0.79, 0.38), Vector3(-0.40 + c4 * 0.40, 0.40, 0), pm, root, false)
			office._box(Vector3(0.30, 0.28, 0.30), Vector3(-0.20, 0.21, 0),
				office._mat("sp_bin3", Color(0.35, 0.37, 0.40)), root, false)
			_sph(0.06, Vector3(0.20, 0.66, 0), green, root)
		"bentchair":
			for sx in [-0.24, 0.24]:
				var side: MeshInstance3D = office._box(Vector3(0.03, 0.55, 0.55),
					Vector3(sx, 0.30, 0.02), ply, root, false)
				side.rotation_degrees = Vector3(-6, 0, 0)
				var arm: MeshInstance3D = office._box(Vector3(0.03, 0.03, 0.48),
					Vector3(sx, 0.56, 0.02), ply, root, false)
				arm.rotation_degrees = Vector3(-4, 0, 0)
			var seat: MeshInstance3D = office._box(Vector3(0.46, 0.07, 0.48),
				Vector3(0, 0.36, 0.04), white, root, false)
			seat.rotation_degrees = Vector3(-4, 0, 0)
			var back: MeshInstance3D = office._box(Vector3(0.46, 0.50, 0.06),
				Vector3(0, 0.62, -0.20), white, root, false)
			back.rotation_degrees = Vector3(-14, 0, 0)
		"stepstool":
			for stp in [[0.18, 0.15], [0.36, -0.05]]:
				office._box(Vector3(0.40, 0.035, 0.20), Vector3(0, stp[0], stp[1]), wood, root, false)
			for sx in [-0.18, 0.18]:
				var sts: MeshInstance3D = office._box(Vector3(0.03, 0.38, 0.34),
					Vector3(sx, 0.19, 0.04), wood, root, false)
				sts.rotation_degrees = Vector3(-8, 0, 0)
		"mirror_full":
			var mf: MeshInstance3D = office._box(Vector3(0.50, 1.85, 0.04),
				Vector3(0, 0.92, -0.02), white, root, false)
			mf.rotation_degrees = Vector3(-5, 0, 0)
			var mg2: MeshInstance3D = office._box(Vector3(0.42, 1.74, 0.01),
				Vector3(0, 0.92, 0.008), office._mat("sp_mirror", Color(0.72, 0.80, 0.84)), root, false)
			mg2.rotation_degrees = Vector3(-5, 0, 0)
		"paperlamp":
			_cyl(0.10, 0.13, 0.03, Vector3(0, 0.015, 0), black, root)
			_cyl(0.012, 0.012, 1.0, Vector3(0, 0.53, 0), black, root)
			_sph(0.20, Vector3(0, 1.20, 0), _emat(Color(0.98, 0.95, 0.88), 0.85), root)
			_omni(Vector3(0, 1.2, 0), Color(1.0, 0.93, 0.80), 0.9, 2.8, root)
		"rug_lines":
			office._box(Vector3(1.60, 0.012, 1.05), Vector3(0, 0.006, 0),
				office._mat("sp_rugw", Color(0.92, 0.90, 0.86)), root, false)
			for i in 4:
				office._box(Vector3(1.45, 0.006, 0.03), Vector3(0, 0.014, -0.36 + i * 0.24),
					black, root, false)
		"throw":
			office._box(Vector3(0.40, 0.06, 0.30), Vector3(0, 0.03, 0),
				office._mat("sp_c_9eab91", Color.html("9eab91")), root, false)
			office._box(Vector3(0.36, 0.05, 0.26), Vector3(0.01, 0.08, 0),
				office._mat("sp_c_d9cbb0", Color.html("d9cbb0")), root, false)
			office._box(Vector3(0.38, 0.01, 0.04), Vector3(0, 0.015, 0.16), white, root, false)
		"ladder":
			for rx in [-0.22, 0.22]:
				var lr: MeshInstance3D = office._box(Vector3(0.04, 1.75, 0.04),
					Vector3(rx, 0.86, -0.02), wood, root, false)
				lr.rotation_degrees = Vector3(-10, 0, 0)
			for i in 3:
				var rung: MeshInstance3D = _cyl(0.015, 0.015, 0.44,
					Vector3(0, 0.45 + i * 0.45, -0.09 + i * 0.08), wood, root, Vector3(0, 0, 90))
				rung.rotation_degrees = Vector3(0, 0, 90)
			office._box(Vector3(0.38, 0.35, 0.02), Vector3(0, 0.75, 0.02),
				office._mat("sp_c_b3705c", Color.html("b3705c")), root, false)
		"hookrack":
			office._box(Vector3(0.80, 0.06, 0.03), Vector3(0, 0.1, 0), wood, root, false)
			for i in 4:
				_cyl(0.012, 0.012, 0.06, Vector3(-0.28 + i * 0.19, 0.07, 0.03), black, root,
					Vector3(60, 0, 0))
			office._box(Vector3(0.20, 0.26, 0.05), Vector3(-0.09, -0.09, 0.03),
				office._mat("sp_tote", Color(0.85, 0.80, 0.70)), root, false)
		"traytable":
			_cyl(0.26, 0.26, 0.03, Vector3(0, 0.44, 0), black, root)
			_cyl(0.24, 0.24, 0.025, Vector3(0, 0.46, 0),
				office._mat("sp_ply", Color(0.78, 0.66, 0.48)), root)
			for xa in [16.0, -16.0]:
				var xl: MeshInstance3D = office._box(Vector3(0.03, 0.48, 0.03),
					Vector3(0, 0.22, 0), black, root, false)
				xl.rotation_degrees = Vector3(xa, 0, 0)
				var xl2: MeshInstance3D = office._box(Vector3(0.03, 0.48, 0.03),
					Vector3(0, 0.22, 0), black, root, false)
				xl2.rotation_degrees = Vector3(0, 90, xa)
		"standscandi":
			_cyl(0.14, 0.14, 0.03, Vector3(0, 0.42, 0), wood, root)
			for i in 3:
				var ang := i * TAU / 3.0
				var pleg: MeshInstance3D = office._box(Vector3(0.03, 0.44, 0.03),
					Vector3(cos(ang) * 0.10, 0.20, sin(ang) * 0.10), wood, root, false)
				pleg.rotation_degrees = Vector3(sin(ang) * 6.0, 0, cos(ang) * -6.0)
			_cyl(0.10, 0.08, 0.14, Vector3(0, 0.51, 0), white, root)
			_sph(0.10, Vector3(0, 0.65, 0), dgreen, root)
		"organizer":
			_cyl(0.035, 0.035, 0.10, Vector3(-0.10, 0.05, 0), black, root)
			for i in 3:
				var pen2: MeshInstance3D = _cyl(0.004, 0.004, 0.13,
					Vector3(-0.10 + i * 0.012 - 0.012, 0.11, 0),
					[black, office._mat("sp_red", Color(0.80, 0.20, 0.20)), metal][i], root)
				pen2.rotation_degrees = Vector3(i * 6.0 - 6.0, 0, i * 5.0 - 5.0)
			for i in 2:
				office._box(Vector3(0.24, 0.015, 0.16), Vector3(0.08, 0.02 + i * 0.05, 0),
					[black, wood][i], root, false)
		"monstand":
			office._box(Vector3(0.50, 0.025, 0.22), Vector3(0, 0.10, 0), ply, root, false)
			for sx in [-0.22, 0.22]:
				office._box(Vector3(0.025, 0.09, 0.20), Vector3(sx, 0.045, 0), ply, root, false)
		"floatshelf":
			office._box(Vector3(0.80, 0.045, 0.22), Vector3(0, 0.0, 0), pm, root, false)
			var fbc := [Color(0.42, 0.52, 0.65), Color(0.80, 0.51, 0.40), Color(0.62, 0.67, 0.57)]
			for i in 3:
				office._box(Vector3(0.035, 0.16, 0.12), Vector3(-0.2 + i * 0.05, 0.10, 0),
					office._mat("sp_fb%d" % i, fbc[i]), root, false)
			_sph(0.045, Vector3(0.25, 0.06, 0), green, root)
		# ------------------------------------------------- special pack
		"arcade":
			office._box(Vector3(0.70, 1.55, 0.70), Vector3(0, 0.78, 0),
				office._mat("sp_arc", Color(0.18, 0.20, 0.30)), root, false)
			var asc: MeshInstance3D = office._box(Vector3(0.55, 0.42, 0.02),
				Vector3(0, 1.22, 0.32), _emat(Color(0.30, 0.75, 0.85), 1.4), root, false)
			asc.rotation_degrees = Vector3(-10, 0, 0)
			var apn: MeshInstance3D = office._box(Vector3(0.60, 0.04, 0.30),
				Vector3(0, 0.92, 0.42), black, root, false)
			apn.rotation_degrees = Vector3(-15, 0, 0)
			_cyl(0.015, 0.015, 0.07, Vector3(-0.12, 0.98, 0.44), metal, root, Vector3(-15, 0, 0))
			_sph(0.025, Vector3(-0.12, 1.02, 0.45), office._mat("sp_red", Color(0.80, 0.20, 0.20)), root)
			for i in 2:
				_sph(0.018, Vector3(0.08 + i * 0.09, 0.945 - i * 0.02, 0.445),
					[office._mat("sp_red", Color(0.80, 0.20, 0.20)),
					office._mat("sp_c_e8c93f", Color.html("e8c93f"))][i], root)
			office._box(Vector3(0.70, 0.22, 0.10), Vector3(0, 1.62, 0.30),
				_emat(Color(0.95, 0.35, 0.55), 1.5), root, false)
			_omni(Vector3(0, 1.3, 0.6), Color(0.6, 0.6, 1.0), 0.6, 1.8, root)
		"pinball":
			for lx in [-0.28, 0.28]:
				for lz in [-0.5, 0.5]:
					office._box(Vector3(0.06, 0.75, 0.06), Vector3(lx, 0.38, lz), black, root, false)
			var pb: MeshInstance3D = office._box(Vector3(0.62, 0.14, 1.15),
				Vector3(0, 0.83, 0), office._mat("sp_arc", Color(0.18, 0.20, 0.30)), root, false)
			pb.rotation_degrees = Vector3(-6, 0, 0)
			var pg: MeshInstance3D = office._box(Vector3(0.55, 0.02, 1.05),
				Vector3(0, 0.91, 0.01), _emat(Color(0.90, 0.60, 0.75), 0.9), root, false)
			pg.rotation_degrees = Vector3(-6, 0, 0)
			office._box(Vector3(0.62, 0.45, 0.08), Vector3(0, 1.28, -0.56),
				_emat(Color(0.95, 0.55, 0.30), 1.3), root, false)
			_omni(Vector3(0, 1.1, 0), Color(1.0, 0.6, 0.6), 0.5, 1.5, root)
		"dartboard":
			_cyl(0.24, 0.24, 0.05, Vector3(0, 0.1, 0), black, root, Vector3(90, 0, 0))
			var dbc := [Color(0.85, 0.80, 0.65), Color(0.20, 0.55, 0.35), Color(0.80, 0.25, 0.25)]
			var dbr := [0.20, 0.13, 0.06]
			for i in 3:
				_cyl(dbr[i], dbr[i], 0.01, Vector3(0, 0.1, 0.026 + i * 0.004),
					office._mat("sp_db%d" % i, dbc[i]), root, Vector3(90, 0, 0))
			for i in 2:
				var dart: MeshInstance3D = _cyl(0.005, 0.005, 0.10,
					Vector3(0.04 - i * 0.09, 0.14 - i * 0.05, 0.09),
					office._mat("sp_c_e8c93f", Color.html("e8c93f")), root)
				dart.rotation_degrees = Vector3(80, 0, i * 20.0 - 10.0)
		"foosball":
			office._box(Vector3(1.30, 0.28, 0.75), Vector3(0, 0.72, 0),
				office._mat("sp_c_2a7f86", Color.html("2a7f86")), root, false)
			office._box(Vector3(1.22, 0.02, 0.67), Vector3(0, 0.87, 0),
				office._mat("sp_felt", Color(0.15, 0.45, 0.28)), root, false)
			for lx in [-0.55, 0.55]:
				for lz in [-0.28, 0.28]:
					office._box(Vector3(0.07, 0.60, 0.07), Vector3(lx, 0.30, lz), black, root, false)
			for i in 4:
				var rod := _cyl(0.012, 0.012, 0.95, Vector3(-0.45 + i * 0.30, 0.90, 0),
					metal, root, Vector3(90, 0, 0))
				rod.rotation_degrees = Vector3(90, 0, 0)
				_sph(0.03, Vector3(-0.45 + i * 0.30, 0.90, 0.50), black, root)
				for m2 in 2:
					office._box(Vector3(0.035, 0.09, 0.02),
						Vector3(-0.45 + i * 0.30, 0.86, -0.15 + m2 * 0.3),
						[office._mat("sp_red", Color(0.80, 0.20, 0.20)),
						office._mat("sp_c_33415e", Color.html("33415e"))][(i + m2) % 2], root, false)
		"hoop":
			office._box(Vector3(0.70, 0.10, 0.50), Vector3(0, 0.05, -0.25), black, root, false)
			_cyl(0.035, 0.035, 2.5, Vector3(0, 1.3, -0.4), metal, root)
			office._box(Vector3(0.90, 0.60, 0.03), Vector3(0, 2.6, -0.25), white, root, false)
			office._box(Vector3(0.30, 0.22, 0.01), Vector3(0, 2.48, -0.235),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root, false)
			var hring := MeshInstance3D.new()
			var htor := TorusMesh.new()
			htor.inner_radius = 0.17
			htor.outer_radius = 0.21
			hring.mesh = htor
			hring.material_override = office._mat("sp_orange", Color(0.90, 0.45, 0.15))
			hring.position = Vector3(0, 2.38, 0.0)
			root.add_child(hring)
			for i in 5:
				var ang := i * TAU / 5.0
				var net: MeshInstance3D = office._box(Vector3(0.008, 0.30, 0.008),
					Vector3(cos(ang) * 0.14, 2.22, sin(ang) * 0.14), white, root, false)
				net.rotation_degrees = Vector3(sin(ang) * 12.0, 0, cos(ang) * -12.0)
		"guitar":
			for i in 3:
				var ang := i * TAU / 3.0
				var gl: MeshInstance3D = _cyl(0.01, 0.01, 0.45,
					Vector3(cos(ang) * 0.12, 0.22, sin(ang) * 0.12), black, root)
				gl.rotation_degrees = Vector3(sin(ang) * 18.0, 0, cos(ang) * -18.0)
			var gb1 := _sph(0.16, Vector3(0, 0.35, 0.06), office._mat("sp_orange", Color(0.90, 0.45, 0.15)), root)
			gb1.scale = Vector3(1, 1.15, 0.35)
			var gb2 := _sph(0.12, Vector3(0, 0.56, 0.06), office._mat("sp_orange", Color(0.90, 0.45, 0.15)), root)
			gb2.scale = Vector3(1, 0.9, 0.35)
			_cyl(0.035, 0.035, 0.015, Vector3(0, 0.40, 0.115), black, root, Vector3(90, 0, 0))
			var gn: MeshInstance3D = office._box(Vector3(0.045, 0.55, 0.03),
				Vector3(0, 0.90, 0.05), dwood, root, false)
			gn.rotation_degrees = Vector3(4, 0, 0)
			office._box(Vector3(0.06, 0.12, 0.035), Vector3(0, 1.20, 0.04), black, root, false)
		"drums":
			var kick: MeshInstance3D = _cyl(0.28, 0.28, 0.30, Vector3(0, 0.28, 0),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root, Vector3(90, 0, 0))
			kick.rotation_degrees = Vector3(90, 0, 0)
			_cyl(0.26, 0.26, 0.01, Vector3(0, 0.28, 0.16), white, root, Vector3(90, 0, 0))
			for tm in [[-0.20, 0.72, 0.13], [0.20, 0.72, 0.13]]:
				_cyl(tm[2], tm[2], 0.16, Vector3(tm[0], tm[1], -0.05),
					office._mat("sp_red", Color(0.80, 0.20, 0.20)), root)
			_cyl(0.16, 0.16, 0.12, Vector3(-0.42, 0.55, 0.15), white, root)
			_cyl(0.015, 0.015, 0.5, Vector3(-0.42, 0.28, 0.15), metal, root)
			for cym in [[-0.62, 1.05, 0.0], [0.55, 1.0, -0.1]]:
				_cyl(0.015, 0.015, 1.0, Vector3(cym[0], 0.5, cym[2]), metal, root)
				var cd: MeshInstance3D = _cyl(0.19, 0.19, 0.012, Vector3(cym[0], cym[1], cym[2]),
					_emat(Color(0.85, 0.70, 0.30), 0.4), root)
				cd.rotation_degrees = Vector3(6, 0, 4)
		"djbooth":
			office._box(Vector3(1.60, 0.90, 0.60), Vector3(0, 0.45, 0), black, root, false)
			office._box(Vector3(1.60, 0.06, 0.02), Vector3(0, 0.45, 0.31),
				_emat(Color(0.95, 0.35, 0.55), 1.8), root, false)
			for tx in [-0.5, 0.5]:
				_cyl(0.16, 0.16, 0.03, Vector3(tx, 0.93, 0), black, root)
				_cyl(0.13, 0.13, 0.015, Vector3(tx, 0.95, 0),
					office._mat("sp_arc", Color(0.18, 0.20, 0.30)), root)
				_sph(0.02, Vector3(tx, 0.96, 0), metal, root)
			office._box(Vector3(0.40, 0.06, 0.35), Vector3(0, 0.94, 0), metal, root, false)
			for i in 4:
				_sph(0.012, Vector3(-0.12 + i * 0.08, 0.98, 0.08),
					_emat([Color(0.3, 0.9, 0.4), Color(0.95, 0.75, 0.2)][i % 2], 2.0), root)
			_omni(Vector3(0, 1.0, 0.5), Color(1.0, 0.45, 0.70), 0.9, 2.6, root)
		"karaoke":
			office._box(Vector3(0.55, 1.15, 0.45), Vector3(0, 0.58, 0),
				office._mat("sp_arc", Color(0.18, 0.20, 0.30)), root, false)
			office._box(Vector3(0.42, 0.30, 0.02), Vector3(0, 0.95, 0.23),
				_emat(Color(0.35, 0.65, 0.95), 1.2), root, false)
			for mx in [-0.12, 0.12]:
				_cyl(0.012, 0.012, 0.16, Vector3(mx, 0.55, 0.24), black, root, Vector3(30, 0, mx * 200.0))
				_sph(0.028, Vector3(mx - mx * 0.4, 0.64, 0.28), metal, root)
			office._box(Vector3(0.55, 0.04, 0.02), Vector3(0, 0.30, 0.23),
				_emat(Color(0.95, 0.35, 0.55), 1.4), root, false)
			_omni(Vector3(0, 0.9, 0.4), Color(0.5, 0.6, 1.0), 0.5, 1.6, root)
		"claw":
			office._box(Vector3(0.75, 0.80, 0.70), Vector3(0, 0.40, 0),
				office._mat("sp_c_c14b3f", Color.html("c14b3f")), root, false)
			office._box(Vector3(0.70, 0.75, 0.02), Vector3(0, 1.22, 0.33), _glass_mat(), root, false)
			for gx3 in [-0.34, 0.34]:
				office._box(Vector3(0.02, 0.75, 0.65), Vector3(gx3, 1.22, 0), _glass_mat(), root, false)
			var prizes := [Color(0.9, 0.5, 0.6), Color(0.5, 0.7, 0.9), Color(0.95, 0.8, 0.4),
				Color(0.6, 0.85, 0.6), Color(0.8, 0.6, 0.9)]
			for i in prizes.size():
				_sph(0.07, Vector3(-0.2 + (i % 3) * 0.2, 0.88, -0.1 + (i / 3) * 0.2),
					office._mat("sp_pz%d" % i, prizes[i]), root)
			_cyl(0.008, 0.008, 0.25, Vector3(0.05, 1.45, 0), metal, root)
			for i in 3:
				var hk: MeshInstance3D = office._box(Vector3(0.01, 0.08, 0.01),
					Vector3(0.05 + cos(i * TAU / 3.0) * 0.03, 1.30, sin(i * TAU / 3.0) * 0.03),
					metal, root, false)
				hk.rotation_degrees = Vector3(sin(i * TAU / 3.0) * 25.0, 0, cos(i * TAU / 3.0) * 25.0)
			office._box(Vector3(0.75, 0.18, 0.72), Vector3(0, 1.68, 0),
				_emat(Color(0.95, 0.75, 0.30), 1.2), root, false)
			_omni(Vector3(0, 1.2, 0.4), Color(1.0, 0.85, 0.5), 0.7, 1.8, root)
		"telescope":
			for i in 3:
				var ang := i * TAU / 3.0
				var tleg: MeshInstance3D = _cyl(0.015, 0.015, 1.1,
					Vector3(cos(ang) * 0.25, 0.52, sin(ang) * 0.25), wood, root)
				tleg.rotation_degrees = Vector3(sin(ang) * 22.0, 0, cos(ang) * -22.0)
			var tube: MeshInstance3D = _cyl(0.07, 0.09, 0.85, Vector3(0, 1.25, 0.05),
				office._mat("sp_c_33415e", Color.html("33415e")), root)
			tube.rotation_degrees = Vector3(-52, 0, 0)
			var eye: MeshInstance3D = _cyl(0.025, 0.025, 0.10, Vector3(0, 0.95, -0.25), black, root)
			eye.rotation_degrees = Vector3(-52, 0, 0)
		"robot":
			office._box(Vector3(0.40, 0.50, 0.30), Vector3(0, 0.55, 0), white, root, false)
			office._box(Vector3(0.30, 0.24, 0.24), Vector3(0, 0.95, 0), white, root, false)
			for ex in [-0.07, 0.07]:
				_sph(0.030, Vector3(ex, 0.97, 0.115), _emat(Color(0.30, 0.75, 0.95), 2.0), root)
			office._box(Vector3(0.14, 0.02, 0.01), Vector3(0, 0.89, 0.12),
				_emat(Color(0.30, 0.75, 0.95), 1.2), root, false)
			_cyl(0.008, 0.008, 0.10, Vector3(0, 1.12, 0), metal, root)
			_sph(0.022, Vector3(0, 1.18, 0), _emat(Color(0.95, 0.45, 0.55), 2.2), root)
			for ax2 in [-0.24, 0.24]:
				var arm2: MeshInstance3D = office._box(Vector3(0.06, 0.34, 0.08),
					Vector3(ax2, 0.55, 0.02), metal, root, false)
				arm2.rotation_degrees = Vector3(0, 0, ax2 * -30.0)
			_cyl(0.14, 0.14, 0.10, Vector3(0, 0.15, 0), black, root, Vector3(90, 0, 0))
			_omni(Vector3(0, 1.0, 0.3), Color(0.4, 0.8, 1.0), 0.4, 1.2, root)
		"treadmill":
			office._box(Vector3(0.70, 0.14, 1.60), Vector3(0, 0.08, 0.1), black, root, false)
			office._box(Vector3(0.50, 0.02, 1.35), Vector3(0, 0.16, 0.15),
				office._mat("sp_belt", Color(0.20, 0.21, 0.24)), root, false)
			for rx2 in [-0.28, 0.28]:
				var rail: MeshInstance3D = office._box(Vector3(0.04, 0.95, 0.06),
					Vector3(rx2, 0.55, -0.55), metal, root, false)
				rail.rotation_degrees = Vector3(18, 0, 0)
				office._box(Vector3(0.04, 0.04, 0.55), Vector3(rx2, 1.02, -0.32), metal, root, false)
			office._box(Vector3(0.50, 0.28, 0.05), Vector3(0, 1.15, -0.68),
				_emat(Color(0.30, 0.70, 0.75), 0.9), root, false)
		"massagechair":
			office._box(Vector3(0.80, 0.30, 0.70), Vector3(0, 0.25, 0), black, root, false)
			office._box(Vector3(0.55, 0.14, 0.55), Vector3(0, 0.44, 0.05),
				office._mat("sp_arc", Color(0.18, 0.20, 0.30)), root, false)
			var mback: MeshInstance3D = office._box(Vector3(0.55, 0.85, 0.22),
				Vector3(0, 0.80, -0.32), office._mat("sp_arc", Color(0.18, 0.20, 0.30)), root, false)
			mback.rotation_degrees = Vector3(-16, 0, 0)
			for px5 in [-0.34, 0.34]:
				office._box(Vector3(0.14, 0.42, 0.60), Vector3(px5, 0.48, 0.02), black, root, false)
			var mleg: MeshInstance3D = office._box(Vector3(0.48, 0.20, 0.45),
				Vector3(0, 0.28, 0.48), black, root, false)
			mleg.rotation_degrees = Vector3(24, 0, 0)
			_sph(0.01, Vector3(0.34, 0.72, 0.28), _emat(Color(0.3, 0.9, 0.4), 2.0), root)
		"popcorn":
			for wx3 in [-0.25, 0.25]:
				_cyl(0.07, 0.07, 0.03, Vector3(wx3, 0.07, 0.28),
					office._mat("sp_c_e8c93f", Color.html("e8c93f")), root, Vector3(90, 0, 0))
			office._box(Vector3(0.60, 0.55, 0.55), Vector3(0, 0.42, 0),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root, false)
			office._box(Vector3(0.55, 0.60, 0.50), Vector3(0, 1.0, 0), _glass_mat(), root, false)
			for i in 6:
				_sph(0.045, Vector3(-0.15 + (i % 3) * 0.15, 0.78 + (i / 3) * 0.07, (i % 2) * 0.1 - 0.05),
					_emat(Color(0.98, 0.92, 0.70), 0.4), root)
			office._box(Vector3(0.60, 0.12, 0.55), Vector3(0, 1.36, 0),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root, false)
			office._box(Vector3(0.40, 0.06, 0.02), Vector3(0, 1.0, 0.26),
				_emat(Color(0.95, 0.85, 0.55), 1.2), root, false)
			_omni(Vector3(0, 1.0, 0.4), Color(1.0, 0.85, 0.55), 0.6, 1.6, root)
		"coffeecart":
			for wx4 in [-0.35, 0.35]:
				_cyl(0.10, 0.10, 0.04, Vector3(wx4, 0.10, 0.25), black, root, Vector3(90, 0, 0))
			office._box(Vector3(1.00, 0.55, 0.55), Vector3(0, 0.48, 0), wood, root, false)
			office._box(Vector3(1.06, 0.05, 0.60), Vector3(0, 0.78, 0), dwood, root, false)
			office._box(Vector3(0.30, 0.28, 0.25), Vector3(-0.25, 0.95, 0), metal, root, false)
			for i in 2:
				_cyl(0.025, 0.02, 0.05, Vector3(0.15 + i * 0.12, 0.83, 0.1), white, root)
			office._box(Vector3(0.35, 0.45, 0.03), Vector3(0.3, 1.15, -0.15), dwood, root, false)
			office._box(Vector3(0.28, 0.30, 0.01), Vector3(0.3, 1.17, -0.13),
				office._mat("sp_slate", Color(0.13, 0.14, 0.15)), root, false)
			office._box(Vector3(0.18, 0.02, 0.005), Vector3(0.3, 1.24, -0.12), white, root, false)
		"photobooth":
			office._box(Vector3(1.00, 2.10, 0.95), Vector3(0, 1.05, 0),
				office._mat("sp_c_33415e", Color.html("33415e")), root, false)
			office._box(Vector3(0.45, 1.55, 0.03), Vector3(-0.22, 0.85, 0.47),
				office._mat("sp_c_c14b3f", Color.html("c14b3f")), root, false)
			for fw2 in 3:
				office._box(Vector3(0.05, 1.55, 0.05), Vector3(-0.36 + fw2 * 0.14, 0.85, 0.48),
					office._mat("sp_c_c14b3f", Color.html("c14b3f")), root, false)
			office._box(Vector3(0.85, 0.30, 0.02), Vector3(0, 1.85, 0.48),
				_emat(Color(0.95, 0.75, 0.30), 1.4), root, false)
			office._box(Vector3(0.30, 0.45, 0.02), Vector3(0.25, 1.0, 0.47), white, root, false)
			_omni(Vector3(0, 1.6, 0.7), Color(1.0, 0.85, 0.55), 0.6, 1.8, root)
		"cattree":
			office._box(Vector3(0.70, 0.06, 0.50), Vector3(0, 0.03, 0),
				office._mat("sp_carpet2", Color(0.75, 0.72, 0.66)), root, false)
			for post in [[-0.2, 0.55], [0.18, 0.95]]:
				_cyl(0.055, 0.055, post[1], Vector3(post[0], post[1] / 2.0 + 0.06, 0),
					office._mat("sp_rope", Color(0.82, 0.72, 0.55)), root)
				_cyl(0.16, 0.16, 0.05, Vector3(post[0], post[1] + 0.09, 0),
					office._mat("sp_carpet2", Color(0.75, 0.72, 0.66)), root)
			office._box(Vector3(0.32, 0.28, 0.30), Vector3(-0.2, 0.25, 0.02),
				office._mat("sp_carpet2", Color(0.75, 0.72, 0.66)), root, false)
			_cyl(0.09, 0.09, 0.12, Vector3(-0.2, 0.25, 0.17), black, root, Vector3(90, 0, 0))
			var cat := _sph(0.09, Vector3(0.18, 1.10, 0), office._mat("sp_cat", Color(0.90, 0.65, 0.35)), root)
			cat.scale = Vector3(1.4, 0.75, 1)
			_sph(0.055, Vector3(0.28, 1.14, 0), office._mat("sp_cat", Color(0.90, 0.65, 0.35)), root)
			for ear in [-0.03, 0.03]:
				office._box(Vector3(0.025, 0.035, 0.015), Vector3(0.28 + ear, 1.19, 0),
					office._mat("sp_cat", Color(0.90, 0.65, 0.35)), root, false)
			var tail: MeshInstance3D = _cyl(0.015, 0.02, 0.16, Vector3(0.06, 1.12, 0.05),
				office._mat("sp_cat", Color(0.90, 0.65, 0.35)), root)
			tail.rotation_degrees = Vector3(0, 0, 70)
		"skateboard":
			office._box(Vector3(0.20, 0.015, 0.60), Vector3(0, 0.06, 0),
				pm if params.has("col") else office._mat("sp_c_2a7f86", Color.html("2a7f86")), root, false)
			for kz in [-0.32, 0.32]:
				var kick2: MeshInstance3D = office._box(Vector3(0.20, 0.015, 0.10),
					Vector3(0, 0.075, kz), office._mat("sp_c_2a7f86", Color.html("2a7f86")), root, false)
				kick2.rotation_degrees = Vector3(signf(kz) * -18.0, 0, 0)
			for wx5 in [-0.07, 0.07]:
				for wz in [-0.20, 0.20]:
					_sph(0.022, Vector3(wx5, 0.025, wz), white, root)
		"scooter":
			for wz2 in [-0.45, 0.50]:
				_cyl(0.14, 0.14, 0.06, Vector3(0, 0.14, wz2), black, root, Vector3(90, 0, 0))
				_cyl(0.08, 0.08, 0.065, Vector3(0, 0.14, wz2),
					office._mat("sp_c_d9cbb0", Color.html("d9cbb0")), root, Vector3(90, 0, 0))
			office._box(Vector3(0.16, 0.10, 0.55), Vector3(0, 0.22, 0.05),
				office._mat("sp_c_9eab91", Color.html("9eab91")), root, false)
			office._box(Vector3(0.20, 0.30, 0.35), Vector3(0, 0.32, -0.32),
				office._mat("sp_c_9eab91", Color.html("9eab91")), root, false)
			office._box(Vector3(0.14, 0.08, 0.25), Vector3(0, 0.52, 0.12), black, root, false)
			var col2: MeshInstance3D = _cyl(0.025, 0.025, 0.45, Vector3(0, 0.60, 0.42), metal, root)
			col2.rotation_degrees = Vector3(20, 0, 0)
			_cyl(0.015, 0.015, 0.36, Vector3(0, 0.82, 0.49), black, root, Vector3(0, 0, 90))
			_sph(0.03, Vector3(0.18, 0.82, 0.49), metal, root)
			office._box(Vector3(0.05, 0.14, 0.02), Vector3(0, 0.42, -0.51),
				_emat(Color(0.95, 0.85, 0.55), 0.8), root, false)
		# --------------------------------- the town's own designs, buyable
		"gwall":
			var gnode: Node3D = office._glass_run_piece(0.0, 0.0, float(params.get("w", 2.0)), true,
				office._mat("podglass", Color(0.75, 0.86, 0.94, 0.25), "", Color.BLACK, true),
				office._mat("steel", Color(0.42, 0.42, 0.46)))
			office.remove_child(gnode)
			gnode.position = Vector3.ZERO
			root.add_child(gnode)
			root.add_to_group("wall_surface")
			root.set_meta("snap_mode", "edge")
			root.set_meta("half_len", float(params.get("w", 2.0)) / 2.0)
			root.set_meta("half_t", 0.05)
			gnode.remove_from_group("furniture")
			gnode.remove_from_group("wall_surface")
			var gw2 := float(params.get("w", 2.0))
			for gpx in [-gw2 / 2.0, gw2 / 2.0]:
				office._box(Vector3(0.09, 2.04, 0.09), Vector3(gpx, 1.02, 0),
					office._mat("steel", Color(0.42, 0.42, 0.46)), root, false)
		"shell":
			var sh: Node3D = office._shell_chair(0.0, 0.0, 180.0, Color.html(pchex))
			office.remove_child(sh)
			sh.position = Vector3.ZERO
			sh.remove_from_group("furniture")
			root.add_child(sh)
		"cushion":
			office._box(Vector3(0.55, 0.10, 0.55), Vector3(0, 0.06, 0), pm, root, false)
			office._box(Vector3(0.57, 0.025, 0.57), Vector3(0, 0.115, 0), pm, root, false)
		"desk_office":
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._modern_desk(0.0, 0.0, 1.7)), root)
		"round_office":
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._round_table(0.0, 0.0)), root)
		"bar_office":
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._bar_stool(0.0, 0.0)), root)
		"lamp_office":
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._floor_lamp(0.0, 0.0)), root)
		"tasklamp_office":
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._task_lamp(0.0, 0.0, 180, 0.0)), root)
		"pendant_office":
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._pendant(Vector3(0, 2.4, 0))), root)
		"credenza_office":
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._credenza(0.0, 0.0)), root)
		"tree_office":
			var ts := float(params.get("s", 1.0))
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._tree(Vector3.ZERO, ts)), root)
		"bush_office":
			_adopt(office._movable_call(0.0, 0.0, func() -> void: office._bush(Vector3.ZERO)), root)
		"greenscreen":
			var chroma: StandardMaterial3D = office._mat("chroma", Color(0.28, 0.78, 0.31))
			office._box(Vector3(3.0, 2.2, 0.09), Vector3(0, 1.1, 0), chroma, root, false)
			office._box(Vector3(3.0, 0.02, 1.2), Vector3(0, 0.012, 0.65), chroma, root, false)
			office._box(Vector3(3.1, 0.06, 0.12), Vector3(0, 2.23, 0),
				office._mat("sp_black", Color(0.10, 0.10, 0.12)), root, false)
		# ============ RESEARCHED ORIGINALS WAVE (IKEA archetypes + real
		# electronics-store shelves) — every id below is a NEW silhouette
		"gaming_chair":
			for i in 5:
				var ang := i * TAU / 5.0
				var gcl: MeshInstance3D = office._box(Vector3(0.30, 0.035, 0.05),
					Vector3(cos(ang) * 0.15, 0.03, sin(ang) * 0.15), black, root, false)
				gcl.rotation_degrees = Vector3(0, -rad_to_deg(ang), 0)
				_sph(0.03, Vector3(cos(ang) * 0.28, 0.03, sin(ang) * 0.28), black, root)
			_cyl(0.045, 0.045, 0.25, Vector3(0, 0.18, 0), metal, root)
			office._box(Vector3(0.52, 0.09, 0.50), Vector3(0, 0.36, 0), pm, root, false)
			for wx in [-0.24, 0.24]:
				var gw2: MeshInstance3D = office._box(Vector3(0.07, 0.13, 0.42),
					Vector3(wx, 0.42, 0.02), black, root, false)
				gw2.rotation_degrees = Vector3(0, 0, wx * -35.0)
				office._box(Vector3(0.05, 0.22, 0.05), Vector3(wx, 0.52, 0.18), black, root, false)
				office._box(Vector3(0.14, 0.03, 0.20), Vector3(wx, 0.63, 0.14), black, root, false)
			var gbk: MeshInstance3D = office._box(Vector3(0.50, 0.85, 0.10),
				Vector3(0, 0.80, -0.24), pm, root, false)
			gbk.rotation_degrees = Vector3(-12, 0, 0)
			for wy in [0.62, 1.05]:
				var gwing: MeshInstance3D = office._box(Vector3(0.60, 0.16, 0.09),
					Vector3(0, wy, -0.27 - (wy - 0.62) * 0.09), black, root, false)
				gwing.rotation_degrees = Vector3(-12, 0, 0)
			var ghd: MeshInstance3D = office._box(Vector3(0.26, 0.12, 0.08),
				Vector3(0, 1.18, -0.335), black, root, false)
			ghd.rotation_degrees = Vector3(-12, 0, 0)
		"mesh_chair":
			for i in 5:
				var ang := i * TAU / 5.0
				var mcl: MeshInstance3D = office._box(Vector3(0.28, 0.03, 0.05),
					Vector3(cos(ang) * 0.14, 0.025, sin(ang) * 0.14), metal, root, false)
				mcl.rotation_degrees = Vector3(0, -rad_to_deg(ang), 0)
			_cyl(0.04, 0.04, 0.28, Vector3(0, 0.2, 0), metal, root)
			office._box(Vector3(0.48, 0.07, 0.46), Vector3(0, 0.40, 0), black, root, false)
			var msb: MeshInstance3D = office._box(Vector3(0.46, 0.72, 0.035),
				Vector3(0, 0.78, -0.22), office._mat("sp_mesh", Color(0.25, 0.27, 0.30)), root, false)
			msb.rotation_degrees = Vector3(-8, 0, 0)
			office._box(Vector3(0.40, 0.05, 0.02), Vector3(0, 0.55, -0.185),
				office._mat("sp_lumbar", Color(0.45, 0.48, 0.52)), root, false)
			var mhd: MeshInstance3D = office._box(Vector3(0.30, 0.14, 0.05),
				Vector3(0, 1.22, -0.28), black, root, false)
			mhd.rotation_degrees = Vector3(-14, 0, 0)
			for ax in [-0.26, 0.26]:
				office._box(Vector3(0.04, 0.16, 0.04), Vector3(ax, 0.48, 0.02), black, root, false)
				office._box(Vector3(0.09, 0.03, 0.24), Vector3(ax, 0.57, 0.02), black, root, false)
		"rocking_chair":
			for rx in [-0.26, 0.26]:
				for seg in [[-0.28, 10.0], [0.0, 0.0], [0.28, -10.0]]:
					var run: MeshInstance3D = office._box(Vector3(0.04, 0.03, 0.34),
						Vector3(rx, 0.045 + absf(seg[1]) * 0.004, seg[0]), wood, root, false)
					run.rotation_degrees = Vector3(seg[1], 0, 0)
				office._box(Vector3(0.04, 0.30, 0.04), Vector3(rx, 0.24, 0.16), wood, root, false)
				office._box(Vector3(0.04, 0.62, 0.04), Vector3(rx, 0.40, -0.20), wood, root, false)
			office._box(Vector3(0.55, 0.04, 0.45), Vector3(0, 0.40, 0), wood, root, false)
			for i in 4:
				var slat2: MeshInstance3D = office._box(Vector3(0.50, 0.09, 0.025),
					Vector3(0, 0.52 + i * 0.13, -0.21 - i * 0.025), wood, root, false)
				slat2.rotation_degrees = Vector3(-10, 0, 0)
			office._box(Vector3(0.50, 0.05, 0.40), Vector3(0, 0.445, 0.02),
				office._mat("sp_c_9eab91", Color.html("9eab91")), root, false)
		"egg_swing":
			_cyl(0.30, 0.34, 0.04, Vector3(0, 0.02, -0.25), metal, root)
			var arm3: MeshInstance3D = _cyl(0.03, 0.035, 1.9, Vector3(0, 0.95, -0.35), metal, root)
			arm3.rotation_degrees = Vector3(14, 0, 0)
			_cyl(0.03, 0.03, 0.55, Vector3(0, 1.86, -0.02), metal, root, Vector3(76, 0, 0))
			_cyl(0.008, 0.008, 0.22, Vector3(0, 1.62, 0.18), black, root)
			var eggb := _sph(0.42, Vector3(0, 1.12, 0.18),
				office._mat("sp_rattan", Color(0.72, 0.58, 0.40)), root)
			eggb.scale = Vector3(1, 1.25, 0.95)
			var eggi := _sph(0.36, Vector3(0, 1.10, 0.26), white, root)
			eggi.scale = Vector3(0.95, 1.1, 0.6)
			office._box(Vector3(0.5, 0.10, 0.42), Vector3(0, 0.82, 0.20),
				office._mat("sp_c_e0b4b8", Color.html("e0b4b8")), root, false)
		"sofa_bed":
			office._box(Vector3(2.00, 0.35, 0.90), Vector3(0, 0.28, 0), pm, root, false)
			office._box(Vector3(0.80, 0.35, 0.75), Vector3(0.60, 0.28, 0.825), pm, root, false)
			office._box(Vector3(2.00, 0.50, 0.18), Vector3(0, 0.70, -0.36), pm, root, false)
			office._box(Vector3(1.96, 0.02, 0.86), Vector3(0, 0.465, 0), black, root, false)
			office._box(Vector3(0.02, 0.34, 0.86), Vector3(0.19, 0.28, 0), black, root, false)
			for px in [-0.60, 0.60]:
				office._box(Vector3(0.42, 0.14, 0.12), Vector3(px, 0.56, -0.26), white, root, false)
		"bunk_bed":
			for cx in [-0.95, 0.95]:
				for cz in [-0.45, 0.45]:
					office._box(Vector3(0.07, 1.75, 0.07), Vector3(cx, 0.87, cz), wood, root, false)
			for deck in [0.35, 1.25]:
				office._box(Vector3(1.95, 0.09, 0.95), Vector3(0, deck, 0), wood, root, false)
				office._box(Vector3(1.85, 0.10, 0.85), Vector3(0, deck + 0.09, 0), white, root, false)
				office._box(Vector3(0.5, 0.08, 0.3), Vector3(-0.6, deck + 0.17, -0.2), white, root, false)
			office._box(Vector3(1.90, 0.05, 0.04), Vector3(0, 1.62, 0.44), wood, root, false)
			for i in 4:
				var lr2: MeshInstance3D = office._box(Vector3(0.32, 0.035, 0.035),
					Vector3(0.80, 0.35 + i * 0.30, 0.49), wood, root, false)
				lr2.rotation_degrees = Vector3(0, 0, 0)
			for lx2 in [0.66, 0.94]:
				var lp2: MeshInstance3D = office._box(Vector3(0.04, 1.35, 0.04),
					Vector3(lx2, 0.72, 0.49), wood, root, false)
				lp2.rotation_degrees = Vector3(8, 0, 0)
			office._box(Vector3(0.55, 0.10, 0.30), Vector3(0.55, 0.52, 0.30),
				office._mat("sp_c_33415e", Color.html("33415e")), root, false)
		"storage_bench":
			office._box(Vector3(1.30, 0.06, 0.42), Vector3(0, 0.45, 0), ply, root, false)
			office._box(Vector3(1.30, 0.05, 0.42), Vector3(0, 0.08, 0), ply, root, false)
			for sx in [-0.63, -0.21, 0.21, 0.63]:
				office._box(Vector3(0.04, 0.36, 0.40), Vector3(sx, 0.26, 0), ply, root, false)
			var bin_c := [Color(0.62, 0.67, 0.57), Color(0.80, 0.51, 0.40), Color(0.35, 0.37, 0.40)]
			for i in 3:
				office._box(Vector3(0.32, 0.26, 0.32), Vector3(-0.42 + i * 0.42, 0.245, 0.01),
					office._mat("sp_bb%d" % i, bin_c[i]), root, false)
			office._box(Vector3(1.26, 0.04, 0.38), Vector3(0, 0.50, 0),
				office._mat("sp_c_9eab91", Color.html("9eab91")), root, false)
		"leaf_table":
			var leaf := _sph(0.30, Vector3(0, 0.45, 0), office._mat("sp_leaftop", Color(0.55, 0.30, 0.25)), root)
			leaf.scale = Vector3(1.25, 0.055, 0.85)
			var tip: MeshInstance3D = office._box(Vector3(0.10, 0.016, 0.10),
				Vector3(0.36, 0.45, 0), office._mat("sp_leaftop", Color(0.55, 0.30, 0.25)), root, false)
			tip.rotation_degrees = Vector3(0, 45, 0)
			for i in 3:
				var ang := i * TAU / 3.0 + 0.5
				var ll2: MeshInstance3D = _cyl(0.015, 0.015, 0.45,
					Vector3(cos(ang) * 0.16, 0.22, sin(ang) * 0.13), black, root)
				ll2.rotation_degrees = Vector3(sin(ang) * 12.0, 0, cos(ang) * -12.0)
		"trestle_desk":
			office._box(Vector3(1.50, 0.035, 0.70), Vector3(0, 0.72, 0), white, root, false)
			for tx in [-0.55, 0.55]:
				for ta2 in [16.0, -16.0]:
					var tl2: MeshInstance3D = office._box(Vector3(0.045, 0.72, 0.045),
						Vector3(tx, 0.35, 0), metal, root, false)
					tl2.rotation_degrees = Vector3(ta2, 0, 0)
				office._box(Vector3(0.045, 0.04, 0.50), Vector3(tx, 0.35, 0), metal, root, false)
		"gaming_desk":
			office._box(Vector3(1.60, 0.04, 0.75), Vector3(0, 0.73, 0),
				office._mat("sp_carbon", Color(0.14, 0.15, 0.17)), root, false)
			office._box(Vector3(1.60, 0.015, 0.02), Vector3(0, 0.755, 0.37),
				_emat(Color(0.35, 0.85, 0.95), 1.8), root, false)
			for lx in [-0.72, 0.72]:
				office._box(Vector3(0.10, 0.71, 0.55), Vector3(lx, 0.36, 0), black, root, false)
			office._box(Vector3(0.60, 0.035, 0.24), Vector3(0, 0.83, -0.20), black, root, false)
			var hk: MeshInstance3D = _cyl(0.012, 0.012, 0.10, Vector3(-0.80, 0.62, 0.1),
				black, root, Vector3(0, 0, 90))
			hk.rotation_degrees = Vector3(0, 0, 90)
			_omni(Vector3(0, 0.8, 0.3), Color(0.35, 0.85, 0.95), 0.5, 1.4, root)
		"vanity":
			office._box(Vector3(1.10, 0.05, 0.45), Vector3(0, 0.72, 0), white, root, false)
			for lx in [-0.48, 0.48]:
				office._box(Vector3(0.05, 0.70, 0.40), Vector3(lx, 0.36, 0), white, root, false)
			office._box(Vector3(0.35, 0.12, 0.35), Vector3(0.25, 0.66, 0), white, root, false)
			_cyl(0.26, 0.26, 0.025, Vector3(0, 1.25, -0.19),
				office._mat("sp_mirror", Color(0.72, 0.80, 0.84)), root, Vector3(90, 0, 0))
			_cyl(0.29, 0.29, 0.015, Vector3(0, 1.25, -0.20), white, root, Vector3(90, 0, 0))
			for i in 6:
				var ang := PI * 0.15 + i * PI * 0.14
				_sph(0.022, Vector3(cos(ang) * 0.33, 1.25 + sin(ang) * 0.33, -0.18),
					_emat(Color(1.0, 0.92, 0.78), 1.6), root)
			_cyl(0.16, 0.16, 0.06, Vector3(-0.15, 0.42, 0.45), pm, root)
			for i in 3:
				var ang2 := i * TAU / 3.0
				var vst: MeshInstance3D = office._box(Vector3(0.03, 0.40, 0.03),
					Vector3(-0.15 + cos(ang2) * 0.10, 0.20, 0.45 + sin(ang2) * 0.10), wood, root, false)
				vst.rotation_degrees = Vector3(sin(ang2) * 8.0, 0, cos(ang2) * -8.0)
			_omni(Vector3(0, 1.25, 0.2), Color(1.0, 0.92, 0.78), 0.7, 1.6, root)
		"ext_table":
			var ext := _cyl(0.62, 0.62, 0.05, Vector3(0, 0.72, 0), white, root)
			ext.scale = Vector3(1.3, 1, 1)
			office._box(Vector3(0.03, 0.05, 1.20), Vector3(0, 0.725, 0),
				office._mat("sp_seam", Color(0.78, 0.78, 0.76)), root, false)
			for lx in [-0.62, 0.62]:
				for lz in [-0.40, 0.40]:
					_cyl(0.035, 0.045, 0.70, Vector3(lx, 0.35, lz), white, root)
		"billy":
			office._box(Vector3(0.80, 2.02, 0.30), Vector3(0, 1.01, 0), white, root, false)
			office._box(Vector3(0.72, 1.90, 0.02), Vector3(0, 1.01, -0.13), white, root, false)
			var spine_c := [Color(0.42, 0.52, 0.65), Color(0.80, 0.51, 0.40), Color(0.62, 0.67, 0.57),
				Color(0.85, 0.78, 0.55), Color(0.35, 0.35, 0.40), Color(0.60, 0.42, 0.55)]
			for sh in 5:
				office._box(Vector3(0.72, 0.025, 0.26), Vector3(0, 0.30 + sh * 0.36, 0), white, root, false)
				var bx := -0.30
				var kk := 0
				while bx < 0.28:
					var bw := 0.045 + (kk % 3) * 0.012
					office._box(Vector3(bw, 0.26 - (kk % 4) * 0.02, 0.18),
						Vector3(bx, 0.30 + sh * 0.36 + 0.145, 0),
						office._mat("sp_bl%d" % ((sh + kk) % 6), spine_c[(sh + kk) % 6]), root, false)
					bx += bw + 0.012
					kk += 1
		"pegboard":
			office._box(Vector3(0.76, 0.56, 0.03), Vector3(0, 0.1, 0), white, root, false)
			for hy in 4:
				for hx in 6:
					office._box(Vector3(0.018, 0.018, 0.012),
						Vector3(-0.30 + hx * 0.12, -0.11 + hy * 0.14, 0.017),
						office._mat("sp_seam", Color(0.78, 0.78, 0.76)), root, false)
			office._box(Vector3(0.30, 0.02, 0.10), Vector3(-0.15, 0.13, 0.06), white, root, false)
			_cyl(0.028, 0.028, 0.09, Vector3(-0.20, 0.19, 0.05), white, root)
			_sph(0.035, Vector3(0.18, 0.10, 0.05), green, root)
			for hkx in [0.05, 0.24]:
				_cyl(0.006, 0.006, 0.06, Vector3(hkx, -0.06, 0.04), metal, root, Vector3(60, 0, 0))
			office._box(Vector3(0.05, 0.14, 0.012), Vector3(0.05, -0.14, 0.045),
				office._mat("sp_c_c17a5f", Color.html("c17a5f")), root, false)
		"trofast":
			for sx in [-0.48, 0.48]:
				office._box(Vector3(0.05, 0.95, 0.45), Vector3(sx, 0.48, 0), ply, root, false)
			office._box(Vector3(1.00, 0.05, 0.45), Vector3(0, 0.95, 0), ply, root, false)
			var tro := [Color(0.80, 0.51, 0.40), Color(0.42, 0.52, 0.65), Color(0.62, 0.67, 0.57),
				Color(0.95, 0.85, 0.55), Color(0.35, 0.37, 0.40), Color(0.60, 0.42, 0.55)]
			for row in 3:
				for cx2 in [-0.235, 0.235]:
					office._box(Vector3(0.40, 0.20, 0.40),
						Vector3(cx2, 0.18 + row * 0.28, 0.01),
						office._mat("sp_tro%d" % ((row * 2 + int(cx2 > 0.0)) % 6),
						tro[(row * 2 + int(cx2 > 0.0)) % 6]), root, false)
		"ivar":
			for px in [-0.6, 0.0, 0.6]:
				for pz in [-0.16, 0.16]:
					office._box(Vector3(0.04, 1.55, 0.04), Vector3(px, 0.78, pz), wood, root, false)
				for py in [0.25, 0.75, 1.25]:
					office._box(Vector3(0.03, 0.03, 0.32), Vector3(px, py, 0), wood, root, false)
			for sh2 in [0.28, 0.78, 1.28]:
				office._box(Vector3(1.24, 0.03, 0.34), Vector3(0, sh2, 0), wood, root, false)
			office._box(Vector3(0.25, 0.30, 0.25), Vector3(-0.3, 0.45, 0), white, root, false)
			_sph(0.08, Vector3(0.35, 0.86, 0), green, root)
		"wire_rack":
			for px in [-0.42, 0.42]:
				for pz in [-0.20, 0.20]:
					_cyl(0.014, 0.014, 1.55, Vector3(px, 0.78, pz), metal, root)
			for sh3 in 4:
				office._box(Vector3(0.90, 0.02, 0.44), Vector3(0, 0.14 + sh3 * 0.45, 0), metal, root, false)
				for wl in 5:
					office._box(Vector3(0.88, 0.008, 0.012),
						Vector3(0, 0.155 + sh3 * 0.45, -0.18 + wl * 0.09), metal, root, false)
			office._box(Vector3(0.30, 0.22, 0.30), Vector3(-0.25, 0.72, 0),
				office._mat("sp_c_7da7c9", Color.html("7da7c9")), root, false)
		"clothes_rack":
			for px in [-0.55, 0.55]:
				_cyl(0.02, 0.025, 1.45, Vector3(px, 0.72, 0), metal, root)
				office._box(Vector3(0.06, 0.04, 0.45), Vector3(px, 0.02, 0), metal, root, false)
			_cyl(0.018, 0.018, 1.15, Vector3(0, 1.43, 0), metal, root, Vector3(0, 0, 90))
			var shirt_c := [Color(0.42, 0.52, 0.65), Color(0.92, 0.90, 0.86), Color(0.80, 0.51, 0.40)]
			for i in 3:
				var hx2 := -0.28 + i * 0.28
				_cyl(0.005, 0.005, 0.10, Vector3(hx2, 1.38, 0), metal, root)
				office._box(Vector3(0.26, 0.34, 0.03), Vector3(hx2, 1.13, 0),
					office._mat("sp_sh%d" % i, shirt_c[i]), root, false)
				office._box(Vector3(0.10, 0.06, 0.035), Vector3(hx2, 1.32, 0),
					office._mat("sp_sh%d" % i, shirt_c[i]), root, false)
		"eket_cubes":
			var ek := [[Vector3(-0.28, 0.14, 0), Color(0.62, 0.67, 0.57)],
				[Vector3(0.10, -0.10, 0), Color(0.92, 0.90, 0.86)],
				[Vector3(0.34, 0.22, 0), Color(0.80, 0.51, 0.40)]]
			for e2 in ek:
				office._box(Vector3(0.34, 0.34, 0.24), e2[0],
					office._mat("sp_ek%02x" % int((e2[1] as Color).r * 99), e2[1]), root, false)
				office._box(Vector3(0.28, 0.28, 0.20), (e2[0] as Vector3) + Vector3(0, 0, 0.03),
					office._mat("sp_ekin", Color(0.20, 0.21, 0.24)), root, false)
		"dome_lamp":
			_cyl(0.14, 0.17, 0.03, Vector3(0, 0.015, 0), black, root)
			var dpole: MeshInstance3D = _cyl(0.02, 0.02, 1.55, Vector3(0.05, 0.79, 0), black, root)
			dpole.rotation_degrees = Vector3(0, 0, -6)
			var dome := _sph(0.24, Vector3(0.22, 1.58, 0), black, root)
			dome.scale = Vector3(1, 0.72, 1)
			_cyl(0.16, 0.16, 0.015, Vector3(0.22, 1.47, 0), _emat(Color(1.0, 0.9, 0.72), 1.5), root)
			_omni(Vector3(0.22, 1.38, 0), Color(1.0, 0.88, 0.68), 0.9, 2.6, root)
		"uplight":
			_cyl(0.12, 0.15, 0.03, Vector3(0, 0.015, 0), metal, root)
			_cyl(0.016, 0.016, 1.65, Vector3(0, 0.85, 0), metal, root)
			_cyl(0.12, 0.05, 0.14, Vector3(0, 1.74, 0), metal, root)
			_cyl(0.10, 0.10, 0.01, Vector3(0, 1.81, 0), _emat(Color(1.0, 0.94, 0.80), 1.8), root)
			_omni(Vector3(0, 1.9, 0), Color(1.0, 0.92, 0.75), 0.9, 2.4, root)
		"weave_pendant":
			_cyl(0.008, 0.008, 0.5, Vector3(0, 2.35, 0), black, root)
			for i in 4:
				_cyl(0.30 - i * 0.05, 0.34 - i * 0.05, 0.055,
					Vector3(0, 1.82 + i * 0.075, 0),
					office._mat("sp_rattan", Color(0.72, 0.58, 0.40)), root)
			_sph(0.05, Vector3(0, 1.86, 0), _emat(Color(1.0, 0.88, 0.66), 1.8), root)
			_omni(Vector3(0, 1.8, 0), Color(1.0, 0.86, 0.62), 1.0, 3.0, root)
		"chandelier":
			_cyl(0.008, 0.008, 0.45, Vector3(0, 2.42, 0), black, root)
			_sph(0.06, Vector3(0, 2.16, 0), office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root)
			for i in 6:
				var ang := i * TAU / 6.0
				var carm: MeshInstance3D = _cyl(0.012, 0.012, 0.34,
					Vector3(cos(ang) * 0.17, 2.10, sin(ang) * 0.17),
					office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root)
				carm.rotation_degrees = Vector3(sin(ang) * 75.0, 0, cos(ang) * -75.0)
				_cyl(0.022, 0.028, 0.05, Vector3(cos(ang) * 0.33, 2.13, sin(ang) * 0.33),
					office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root)
				_sph(0.025, Vector3(cos(ang) * 0.33, 2.18, sin(ang) * 0.33),
					_emat(Color(1.0, 0.85, 0.55), 2.0), root)
			_omni(Vector3(0, 2.1, 0), Color(1.0, 0.85, 0.55), 1.1, 3.4, root)
		"cove_bar":
			var cvb: MeshInstance3D = office._box(Vector3(0.90, 0.05, 0.09),
				Vector3(0, 0.03, 0), black, root, false)
			cvb.rotation_degrees = Vector3(0, 0, 0)
			var cvl: MeshInstance3D = office._box(Vector3(0.86, 0.02, 0.04),
				Vector3(0, 0.06, -0.01), _emat(Color.html(pchex) if params.has("col") else Color(0.55, 0.35, 1.0), 2.2), root, false)
			cvl.rotation_degrees = Vector3(-35, 0, 0)
			_omni(Vector3(0, 0.5, -0.2), Color.html(pchex) if params.has("col") else Color(0.55, 0.35, 1.0), 1.0, 2.6, root)
		"macrame_trio":
			_cyl(0.015, 0.015, 1.1, Vector3(0, 1.98, 0), wood, root, Vector3(0, 0, 90))
			for i in 3:
				var mx2 := -0.35 + i * 0.35
				var drop := 0.35 + (i % 2) * 0.18
				_cyl(0.006, 0.006, drop, Vector3(mx2, 1.98 - drop / 2.0, 0), white, root)
				_cyl(0.09, 0.06, 0.12, Vector3(mx2, 1.92 - drop, 0),
					office._mat("sp_macrame", Color(0.90, 0.86, 0.78)), root)
				_sph(0.09, Vector3(mx2, 2.0 - drop, 0), [green, dgreen, green][i], root)
				for vn2 in 2:
					var vine: MeshInstance3D = office._box(Vector3(0.03, 0.22, 0.015),
						Vector3(mx2 + vn2 * 0.08 - 0.04, 1.86 - drop, 0.05), dgreen, root, false)
					vine.rotation_degrees = Vector3(18, vn2 * 60.0, 0)
		"olive_basket":
			_cyl(0.20, 0.16, 0.26, Vector3(0, 0.13, 0),
				office._mat("sp_rattan", Color(0.72, 0.58, 0.40)), root)
			for i in 3:
				_cyl(0.21 - i * 0.01, 0.21 - i * 0.01, 0.02, Vector3(0, 0.06 + i * 0.09, 0),
					office._mat("sp_rattan2", Color(0.62, 0.48, 0.32)), root)
			var otr: MeshInstance3D = _cyl(0.03, 0.045, 0.55, Vector3(0.02, 0.52, 0), dwood, root)
			otr.rotation_degrees = Vector3(0, 0, 8)
			for i in 5:
				var ang := i * TAU / 5.0
				var ol := _sph(0.14, Vector3(cos(ang) * 0.16 + 0.04, 0.90 + sin(ang * 2.0) * 0.08,
					sin(ang) * 0.16), office._mat("sp_olive", Color(0.55, 0.62, 0.50)), root)
				ol.scale = Vector3(1, 0.8, 1)
		"herb_ladder":
			for rx2 in [-0.30, 0.30]:
				var hlr: MeshInstance3D = office._box(Vector3(0.045, 1.45, 0.045),
					Vector3(rx2, 0.70, -0.02), wood, root, false)
				hlr.rotation_degrees = Vector3(-14, 0, 0)
			for i in 4:
				office._box(Vector3(0.62, 0.03, 0.20 - i * 0.02),
					Vector3(0, 0.22 + i * 0.36, -0.24 + i * 0.09), wood, root, false)
				for hp2 in 2:
					_cyl(0.05, 0.04, 0.09, Vector3(-0.15 + hp2 * 0.30, 0.29 + i * 0.36,
						-0.24 + i * 0.09), pot, root)
					_sph(0.055, Vector3(-0.15 + hp2 * 0.30, 0.37 + i * 0.36, -0.24 + i * 0.09),
						[green, dgreen][(i + hp2) % 2], root)
		"cloche":
			_cyl(0.14, 0.15, 0.03, Vector3(0, 0.015, 0), wood, root)
			var cdome := _sph(0.12, Vector3(0, 0.14, 0), _glass_mat(Color(0.85, 0.92, 0.95, 0.22)), root)
			cdome.scale = Vector3(1, 1.3, 1)
			_sph(0.012, Vector3(0, 0.30, 0), _glass_mat(Color(0.85, 0.92, 0.95, 0.4)), root)
			_sph(0.045, Vector3(-0.03, 0.07, 0.02), green, root)
			_sph(0.03, Vector3(0.05, 0.055, -0.02), dgreen, root)
			_cyl(0.02, 0.025, 0.03, Vector3(0.04, 0.045, 0.03),
				office._mat("sp_gravel", Color(0.72, 0.66, 0.55)), root)
		"gallery_ledge":
			office._box(Vector3(0.90, 0.035, 0.09), Vector3(0, 0.0, 0.02), white, root, false)
			var gfr := [[0.20, 0.26, -0.30, Color(0.10, 0.10, 0.12)],
				[0.30, 0.22, 0.02, Color(0.55, 0.42, 0.30)],
				[0.16, 0.20, 0.30, Color(0.10, 0.10, 0.12)]]
			for g2 in gfr:
				var fr2: MeshInstance3D = office._box(Vector3(g2[0], g2[1], 0.02),
					Vector3(g2[2], 0.02 + (g2[1] as float) / 2.0, 0.03),
					office._mat("sp_fr%02x" % int((g2[3] as Color).r * 99), g2[3]), root, false)
				fr2.rotation_degrees = Vector3(-7, 0, 0)
				var inn: MeshInstance3D = office._box(Vector3((g2[0] as float) - 0.05,
					(g2[1] as float) - 0.05, 0.008), Vector3(g2[2], 0.02 + (g2[1] as float) / 2.0, 0.042),
					white, root, false)
				inn.rotation_degrees = Vector3(-7, 0, 0)
		"tapestry":
			_cyl(0.012, 0.012, 0.85, Vector3(0, 0.42, 0), wood, root, Vector3(0, 0, 90))
			office._box(Vector3(0.75, 0.60, 0.015), Vector3(0, 0.08, 0),
				office._mat("sp_tapes", Color(0.85, 0.78, 0.66)), root, false)
			office._box(Vector3(0.75, 0.10, 0.018), Vector3(0, 0.18, 0),
				office._mat("sp_c_c17a5f", Color.html("c17a5f")), root, false)
			office._box(Vector3(0.75, 0.06, 0.018), Vector3(0, -0.02, 0),
				office._mat("sp_c_33415e", Color.html("33415e")), root, false)
			for i in 7:
				office._box(Vector3(0.02, 0.14, 0.012), Vector3(-0.33 + i * 0.11, -0.28, 0),
					office._mat("sp_tapes", Color(0.85, 0.78, 0.66)), root, false)
		"globe_bar":
			for i in 3:
				var ang := i * TAU / 3.0
				var gbl: MeshInstance3D = office._box(Vector3(0.04, 0.55, 0.04),
					Vector3(cos(ang) * 0.20, 0.27, sin(ang) * 0.20), dwood, root, false)
				gbl.rotation_degrees = Vector3(sin(ang) * 10.0, 0, cos(ang) * -10.0)
			var hemi := _sph(0.30, Vector3(0, 0.62, 0), office._mat("sp_globebar", Color(0.45, 0.30, 0.22)), root)
			hemi.scale = Vector3(1, 0.55, 1)
			var lid := _sph(0.30, Vector3(0, 0.78, -0.16), office._mat("sp_globebar", Color(0.45, 0.30, 0.22)), root)
			lid.scale = Vector3(1, 0.55, 1)
			lid.rotation_degrees = Vector3(-55, 0, 0)
			_cyl(0.27, 0.27, 0.015, Vector3(0, 0.70, 0),
				office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root)
			for i in 3:
				_cyl(0.025, 0.03, 0.14, Vector3(-0.10 + i * 0.10, 0.78, 0.02),
					[_glass_mat(Color(0.55, 0.75, 0.45, 0.6)), _glass_mat(Color(0.75, 0.55, 0.30, 0.6)),
					_glass_mat(Color(0.45, 0.55, 0.75, 0.6))][i], root)
		"neon_open":
			office._box(Vector3(0.66, 0.30, 0.03), Vector3(0, 0.1, 0), black, root, false)
			var segs2 := [[-0.22, 0.0], [-0.075, 0.0], [0.075, 0.0], [0.22, 0.0]]
			for i in segs2.size():
				_cyl(0.055, 0.055, 0.02, Vector3(segs2[i][0], 0.1, 0.02),
					_emat(Color(1.0, 0.35, 0.55) if i % 2 == 0 else Color(0.35, 0.85, 0.95), 2.4),
					root, Vector3(90, 0, 0))
				_cyl(0.035, 0.035, 0.025, Vector3(segs2[i][0], 0.1, 0.021), black, root, Vector3(90, 0, 0))
			_omni(Vector3(0, 0.1, 0.3), Color(0.9, 0.5, 0.75), 0.8, 2.0, root)
		"column_aquarium":
			_cyl(0.26, 0.30, 0.14, Vector3(0, 0.07, 0), black, root)
			_cyl(0.22, 0.22, 1.35, Vector3(0, 0.82, 0), _glass_mat(Color(0.45, 0.70, 0.85, 0.30)), root)
			_cyl(0.19, 0.19, 1.25, Vector3(0, 0.80, 0), _glass_mat(Color(0.25, 0.55, 0.75, 0.4)), root)
			_cyl(0.26, 0.26, 0.10, Vector3(0, 1.55, 0), black, root)
			var aqf := [[Color(1.0, 0.55, 0.15), 0.5], [Color(0.95, 0.80, 0.25), 0.85], [Color(0.35, 0.75, 0.85), 1.15]]
			for f2 in aqf:
				var fish2: MeshInstance3D = office._box(Vector3(0.07, 0.035, 0.015),
					Vector3(randf_range(-0.08, 0.08), f2[1], randf_range(-0.06, 0.06)),
					_emat(f2[0], 0.6), root, false)
				fish2.rotation_degrees = Vector3(0, randf_range(0, 360), 0)
			for i in 4:
				_sph(0.012, Vector3(randf_range(-0.1, 0.1), 0.4 + i * 0.28, randf_range(-0.08, 0.08)),
					_glass_mat(Color(0.9, 0.95, 1.0, 0.5)), root)
			_omni(Vector3(0, 1.45, 0), Color(0.55, 0.85, 1.0), 0.8, 2.0, root)
		"tv_wall":
			office._box(Vector3(1.70, 0.95, 0.05), Vector3(0, 0.30, 0), black, root, false)
			office._box(Vector3(1.62, 0.87, 0.015), Vector3(0, 0.30, 0.028),
				_emat(Color(0.18, 0.26, 0.38), 0.8), root, false)
			office._box(Vector3(1.10, 0.09, 0.09), Vector3(0, -0.36, 0.02),
				office._mat("sp_fabricbar", Color(0.30, 0.31, 0.34)), root, false)
			_sph(0.008, Vector3(0.50, -0.36, 0.07), _emat(Color(0.95, 0.75, 0.2), 1.6), root)
		"turntable_set":
			office._box(Vector3(0.55, 0.35, 0.42), Vector3(0, 0.175, 0), wood, root, false)
			office._box(Vector3(0.50, 0.06, 0.38), Vector3(0, 0.39, 0), black, root, false)
			_cyl(0.15, 0.15, 0.015, Vector3(-0.05, 0.435, 0), office._mat("sp_vinyl", Color(0.08, 0.08, 0.09)), root)
			_cyl(0.05, 0.05, 0.02, Vector3(-0.05, 0.44, 0), office._mat("sp_c_c17a5f", Color.html("c17a5f")), root)
			var tarm: MeshInstance3D = _cyl(0.008, 0.008, 0.20, Vector3(0.14, 0.45, -0.06), metal, root)
			tarm.rotation_degrees = Vector3(0, 30, 78)
			for i in 5:
				var vin: MeshInstance3D = office._box(Vector3(0.015, 0.30, 0.30),
					Vector3(0.34 + i * 0.022, 0.15, 0.02),
					office._mat("sp_vs%d" % i, [Color(0.42, 0.52, 0.65), Color(0.80, 0.51, 0.40),
					Color(0.15, 0.15, 0.18), Color(0.62, 0.67, 0.57), Color(0.85, 0.78, 0.55)][i]), root, false)
				vin.rotation_degrees = Vector3(0, 0, i * 2.0 - 4.0)
		"party_speaker":
			office._box(Vector3(0.42, 1.05, 0.38), Vector3(0, 0.53, 0), black, root, false)
			for i in 2:
				_cyl(0.13 - i * 0.05, 0.13 - i * 0.05, 0.015,
					Vector3(0, 0.35 + i * 0.45, 0.195), office._mat("sp_alu", Color(0.75, 0.76, 0.78)),
					root, Vector3(90, 0, 0))
				var ring2 := MeshInstance3D.new()
				var rt := TorusMesh.new()
				rt.inner_radius = 0.13 - i * 0.05
				rt.outer_radius = 0.16 - i * 0.05
				ring2.mesh = rt
				ring2.material_override = _emat([Color(0.35, 0.85, 0.95), Color(1.0, 0.35, 0.55)][i], 2.0)
				ring2.position = Vector3(0, 0.35 + i * 0.45, 0.19)
				ring2.rotation_degrees = Vector3(90, 0, 0)
				root.add_child(ring2)
			office._box(Vector3(0.30, 0.03, 0.06), Vector3(0, 1.08, 0), metal, root, false)
			_omni(Vector3(0, 0.6, 0.4), Color(0.7, 0.5, 0.9), 0.7, 2.0, root)
		"robot_vac":
			var rv := _cyl(0.17, 0.17, 0.07, Vector3(0.25, 0.035, 0.1), white, root)
			_cyl(0.05, 0.05, 0.015, Vector3(0.25, 0.075, 0.1), black, root)
			_sph(0.008, Vector3(0.25, 0.085, 0.1), _emat(Color(0.3, 0.9, 0.4), 2.0), root)
			office._box(Vector3(0.30, 0.14, 0.10), Vector3(0, 0.07, -0.10), black, root, false)
			office._box(Vector3(0.26, 0.015, 0.18), Vector3(0, 0.008, 0.0), black, root, false)
			_sph(0.006, Vector3(-0.08, 0.12, -0.055), _emat(Color(0.35, 0.85, 0.95), 2.0), root)
		"drone_pad":
			_cyl(0.30, 0.30, 0.015, Vector3(0, 0.008, 0), office._mat("sp_padh", Color(0.25, 0.27, 0.32)), root)
			_cyl(0.10, 0.10, 0.005, Vector3(0, 0.02, 0), office._mat("sp_c_e8c93f", Color.html("e8c93f")), root)
			office._box(Vector3(0.16, 0.05, 0.16), Vector3(0, 0.09, 0),
				office._mat("sp_dgray", Color(0.55, 0.57, 0.60)), root, false)
			for ax2 in [-1, 1]:
				for az in [-1, 1]:
					var darm: MeshInstance3D = office._box(Vector3(0.16, 0.02, 0.03),
						Vector3(ax2 * 0.13, 0.10, az * 0.13), black, root, false)
					darm.rotation_degrees = Vector3(0, 45.0 * ax2 * az, 0)
					_cyl(0.07, 0.07, 0.008, Vector3(ax2 * 0.20, 0.12, az * 0.20),
						_glass_mat(Color(0.6, 0.6, 0.65, 0.4)), root)
			_sph(0.012, Vector3(0, 0.13, 0.09), _emat(Color(0.9, 0.2, 0.2), 2.0), root)
		"vr_station":
			office._box(Vector3(0.70, 0.01, 0.70), Vector3(0, 0.006, 0),
				office._mat("sp_c_33415e", Color.html("33415e")), root, false)
			_cyl(0.02, 0.02, 1.1, Vector3(0, 0.55, 0), metal, root)
			_cyl(0.09, 0.11, 0.03, Vector3(0, 0.015, 0), metal, root)
			var hmd: MeshInstance3D = office._box(Vector3(0.20, 0.10, 0.11),
				Vector3(0, 1.14, 0.02), white, root, false)
			hmd.rotation_degrees = Vector3(-10, 0, 0)
			office._box(Vector3(0.18, 0.03, 0.015), Vector3(0, 1.12, 0.085),
				_emat(Color(0.35, 0.55, 0.95), 1.2), root, false)
			for bx3 in [-0.30, 0.30]:
				_cyl(0.012, 0.012, 0.85, Vector3(bx3, 0.42, -0.28), black, root)
				office._box(Vector3(0.06, 0.06, 0.06), Vector3(bx3, 0.88, -0.28), black, root, false)
				_sph(0.008, Vector3(bx3, 0.88, -0.245), _emat(Color(0.3, 0.9, 0.4), 2.2), root)
		"rice_cooker":
			_cyl(0.14, 0.15, 0.16, Vector3(0, 0.08, 0), white, root)
			var rlid := _sph(0.145, Vector3(0, 0.165, 0), white, root)
			rlid.scale = Vector3(1, 0.45, 1)
			_cyl(0.02, 0.02, 0.035, Vector3(0, 0.23, 0), metal, root)
			office._box(Vector3(0.05, 0.025, 0.005), Vector3(0, 0.07, 0.148),
				_emat(Color(0.95, 0.45, 0.30), 1.4), root, false)
			office._box(Vector3(0.03, 0.012, 0.03), Vector3(0.12, 0.10, 0.06), black, root, false)
		"air_fryer":
			office._box(Vector3(0.24, 0.30, 0.28), Vector3(0, 0.15, 0), black, root, false)
			var afc: MeshInstance3D = office._box(Vector3(0.22, 0.20, 0.04),
				Vector3(0, 0.13, 0.145), office._mat("sp_safe", Color(0.25, 0.27, 0.32)), root, false)
			afc.rotation_degrees = Vector3(-6, 0, 0)
			office._box(Vector3(0.14, 0.04, 0.02), Vector3(0, 0.075, 0.16), black, root, false)
			_cyl(0.045, 0.045, 0.008, Vector3(0, 0.27, 0.11),
				_emat(Color(0.35, 0.75, 0.72), 1.0), root, Vector3(72, 0, 0))
		"stand_fan":
			_cyl(0.16, 0.19, 0.03, Vector3(0, 0.015, 0), office._mat("sp_dgray", Color(0.55, 0.57, 0.60)), root)
			_cyl(0.022, 0.022, 0.95, Vector3(0, 0.50, 0), metal, root)
			_cyl(0.19, 0.19, 0.045, Vector3(0, 1.06, 0.02),
				office._mat("sp_dgray", Color(0.55, 0.57, 0.60)), root, Vector3(90, 0, 0))
			for i in 4:
				var blade: MeshInstance3D = office._box(Vector3(0.06, 0.14, 0.008),
					Vector3(cos(i * TAU / 4.0) * 0.09, 1.06 + sin(i * TAU / 4.0) * 0.09, 0.03),
					_glass_mat(Color(0.8, 0.85, 0.9, 0.5)), root, false)
				blade.rotation_degrees = Vector3(0, 0, rad_to_deg(i * TAU / 4.0) + 25.0)
			_sph(0.035, Vector3(0, 1.06, 0.045), metal, root)
		"aircon":
			office._box(Vector3(0.95, 0.30, 0.22), Vector3(0, 0.1, 0), white, root, false)
			office._box(Vector3(0.85, 0.04, 0.02), Vector3(0, -0.03, 0.11),
				office._mat("sp_seam", Color(0.78, 0.78, 0.76)), root, false)
			office._box(Vector3(0.16, 0.04, 0.005), Vector3(0.32, 0.16, 0.111), black, root, false)
			_sph(0.006, Vector3(0.40, 0.02, 0.11), _emat(Color(0.3, 0.9, 0.4), 2.0), root)
		"drink_fridge":
			office._box(Vector3(0.75, 1.80, 0.65), Vector3(0, 0.90, 0),
				office._mat("sp_c_c14b3f", Color.html("c14b3f")), root, false)
			office._box(Vector3(0.58, 1.45, 0.03), Vector3(-0.03, 0.90, 0.32), _glass_mat(), root, false)
			var canc := [Color(0.80, 0.20, 0.20), Color(0.30, 0.60, 0.30), Color(0.95, 0.65, 0.15),
				Color(0.35, 0.45, 0.85)]
			for sh4 in 4:
				office._box(Vector3(0.54, 0.02, 0.45), Vector3(-0.03, 0.35 + sh4 * 0.35, 0.05),
					white, root, false)
				for cc2 in 4:
					_cyl(0.035, 0.035, 0.12, Vector3(-0.22 + cc2 * 0.13, 0.43 + sh4 * 0.35, 0.13),
						office._mat("sp_can%d" % ((sh4 + cc2) % 4), canc[(sh4 + cc2) % 4]), root)
			office._box(Vector3(0.70, 0.16, 0.02), Vector3(0, 1.72, 0.33),
				_emat(Color(0.95, 0.92, 0.85), 1.5), root, false)
			_omni(Vector3(0, 1.0, 0.5), Color(0.85, 0.92, 1.0), 0.7, 1.6, root)
		"pos_counter":
			office._box(Vector3(1.30, 0.95, 0.60), Vector3(0, 0.48, 0), white, root, false)
			office._box(Vector3(1.36, 0.05, 0.66), Vector3(0, 0.98, 0), ply, root, false)
			var poss: MeshInstance3D = office._box(Vector3(0.30, 0.22, 0.02),
				Vector3(-0.30, 1.18, 0), _emat(Color(0.30, 0.70, 0.75), 0.9), root, false)
			poss.rotation_degrees = Vector3(-16, 25, 0)
			_cyl(0.03, 0.05, 0.14, Vector3(-0.30, 1.07, 0), black, root)
			office._box(Vector3(0.30, 0.10, 0.35), Vector3(0.30, 1.05, 0), black, root, false)
			office._box(Vector3(0.10, 0.14, 0.06), Vector3(0.05, 1.08, 0.18), black, root, false)
			office._box(Vector3(0.28, 0.06, 0.33), Vector3(0.30, 0.94, 0.02), metal, root, false)
		"gondola":
			office._box(Vector3(1.40, 0.10, 0.80), Vector3(0, 0.05, 0),
				office._mat("sp_dgray", Color(0.55, 0.57, 0.60)), root, false)
			office._box(Vector3(1.40, 1.45, 0.10), Vector3(0, 0.78, 0),
				office._mat("sp_dgray", Color(0.55, 0.57, 0.60)), root, false)
			var prod := [Color(0.80, 0.20, 0.20), Color(0.95, 0.65, 0.15), Color(0.35, 0.45, 0.85),
				Color(0.30, 0.60, 0.30), Color(0.60, 0.42, 0.55), Color(0.95, 0.85, 0.55)]
			for side in [-1, 1]:
				for sh5 in 3:
					office._box(Vector3(1.30, 0.03, 0.28),
						Vector3(0, 0.45 + sh5 * 0.40, side * 0.24), white, root, false)
					for i in 6:
						office._box(Vector3(0.14, 0.20, 0.10),
							Vector3(-0.55 + i * 0.22, 0.56 + sh5 * 0.40, side * 0.26),
							office._mat("sp_pr%d" % ((sh5 + i) % 6), prod[(sh5 + i) % 6]), root, false)
			office._box(Vector3(1.40, 0.14, 0.12), Vector3(0, 1.55, 0),
				_emat(Color(0.95, 0.92, 0.85), 1.2), root, false)
		"queue_barrier":
			for qx in [-0.6, 0.6]:
				_cyl(0.14, 0.16, 0.02, Vector3(qx, 0.01, 0), metal, root)
				_cyl(0.025, 0.025, 0.95, Vector3(qx, 0.49, 0), metal, root)
				_sph(0.035, Vector3(qx, 0.99, 0), metal, root)
			office._box(Vector3(1.10, 0.06, 0.02), Vector3(0, 0.88, 0),
				office._mat("sp_c_c14b3f", Color.html("c14b3f")), root, false)
		"kitchenette":
			office._box(Vector3(1.60, 0.88, 0.60), Vector3(0, 0.44, 0), white, root, false)
			office._box(Vector3(1.66, 0.05, 0.64), Vector3(0, 0.91, 0), ply, root, false)
			office._box(Vector3(0.45, 0.03, 0.35), Vector3(-0.45, 0.925, 0), metal, root, false)
			office._box(Vector3(0.37, 0.06, 0.27), Vector3(-0.45, 0.91, 0),
				office._mat("sp_safe", Color(0.25, 0.27, 0.32)), root, false)
			var fauc: MeshInstance3D = _cyl(0.015, 0.015, 0.25, Vector3(-0.45, 1.05, -0.13), metal, root)
			fauc.rotation_degrees = Vector3(0, 0, 0)
			_cyl(0.012, 0.012, 0.14, Vector3(-0.45, 1.16, -0.07), metal, root, Vector3(60, 0, 0))
			office._box(Vector3(0.50, 0.015, 0.40), Vector3(0.40, 0.945, 0), black, root, false)
			for i in 2:
				_cyl(0.09, 0.09, 0.005, Vector3(0.28 + i * 0.24, 0.955, 0),
					office._mat("sp_dgray", Color(0.55, 0.57, 0.60)), root)
			office._box(Vector3(0.015, 0.70, 0.60), Vector3(0.0, 0.44, 0.301), white, root, false)
			for hx3 in [-0.55, 0.25]:
				office._box(Vector3(0.16, 0.02, 0.02), Vector3(hx3, 0.62, 0.315), metal, root, false)
		"air_hockey":
			for lx in [-0.75, 0.75]:
				for lz in [-0.35, 0.35]:
					office._box(Vector3(0.14, 0.68, 0.14), Vector3(lx, 0.34, lz), black, root, false)
			office._box(Vector3(1.80, 0.22, 1.00), Vector3(0, 0.79, 0),
				office._mat("sp_c_33415e", Color.html("33415e")), root, false)
			office._box(Vector3(1.66, 0.02, 0.86), Vector3(0, 0.905, 0),
				_emat(Color(0.92, 0.95, 0.98), 0.7), root, false)
			office._box(Vector3(0.02, 0.015, 0.86), Vector3(0, 0.915, 0),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root, false)
			for i in 4:
				_sph(0.01, Vector3(-0.6 + i * 0.4, 0.915, [-0.25, 0.25][i % 2]),
					_emat(Color(0.35, 0.85, 0.95), 1.0), root)
			for mx2 in [-0.5, 0.55]:
				_cyl(0.05, 0.06, 0.03, Vector3(mx2, 0.93, mx2 * 0.3),
					office._mat("sp_red", Color(0.80, 0.20, 0.20)), root)
				_cyl(0.018, 0.018, 0.04, Vector3(mx2, 0.965, mx2 * 0.3),
					office._mat("sp_red", Color(0.80, 0.20, 0.20)), root)
			_cyl(0.035, 0.035, 0.012, Vector3(0.1, 0.92, 0.05), black, root)
			_omni(Vector3(0, 1.2, 0), Color(0.9, 0.95, 1.0), 0.5, 1.8, root)
		"putting_green":
			office._box(Vector3(0.70, 0.03, 2.40), Vector3(0, 0.015, 0),
				office._mat("sp_felt", Color(0.15, 0.45, 0.28)), root, false)
			office._box(Vector3(0.76, 0.05, 2.46), Vector3(0, 0.008, 0), wood, root, false)
			_cyl(0.055, 0.055, 0.012, Vector3(0, 0.032, -0.85), black, root)
			_cyl(0.006, 0.006, 0.5, Vector3(0, 0.28, -0.85), metal, root)
			office._box(Vector3(0.14, 0.09, 0.005), Vector3(0.07, 0.48, -0.85),
				office._mat("sp_red", Color(0.80, 0.20, 0.20)), root, false)
			_sph(0.022, Vector3(0.08, 0.05, 0.75), white, root)
			var club: MeshInstance3D = _cyl(0.008, 0.008, 0.85, Vector3(-0.30, 0.42, 0.9), metal, root)
			club.rotation_degrees = Vector3(12, 0, 18)
		"punching_bag":
			for i in 4:
				var ang := i * TAU / 4.0
				var pbl: MeshInstance3D = office._box(Vector3(0.05, 0.05, 0.75),
					Vector3(cos(ang) * 0.38, 0.025, sin(ang) * 0.38), black, root, false)
				pbl.rotation_degrees = Vector3(0, -rad_to_deg(ang), 0)
			_cyl(0.03, 0.03, 2.2, Vector3(0, 1.1, 0), metal, root)
			office._box(Vector3(0.55, 0.05, 0.05), Vector3(0.22, 2.18, 0), metal, root, false)
			_cyl(0.008, 0.008, 0.25, Vector3(0.45, 2.0, 0), black, root)
			_cyl(0.16, 0.14, 0.85, Vector3(0.45, 1.45, 0),
				office._mat("sp_c_c14b3f", Color.html("c14b3f")), root)
			for i in 2:
				_cyl(0.165, 0.165, 0.02, Vector3(0.45, 1.15 + i * 0.6, 0), black, root)
		"clawfoot_tub":
			var tub := _sph(0.42, Vector3(0, 0.42, 0), white, root)
			tub.scale = Vector3(1.9, 0.75, 1.0)
			var tin := _sph(0.38, Vector3(0, 0.48, 0), _glass_mat(Color(0.55, 0.80, 0.90, 0.55)), root)
			tin.scale = Vector3(1.75, 0.45, 0.85)
			for fx3 in [-0.55, 0.55]:
				for fz in [-0.22, 0.22]:
					var claw2 := _sph(0.06, Vector3(fx3, 0.08, fz),
						office._mat("sp_brass", Color(0.80, 0.65, 0.35)), root)
					claw2.scale = Vector3(0.7, 1.2, 0.7)
			_cyl(0.015, 0.015, 0.30, Vector3(-0.80, 0.60, 0), metal, root)
			_cyl(0.012, 0.012, 0.12, Vector3(-0.76, 0.74, 0), metal, root, Vector3(0, 0, 60))
			for i in 5:
				_sph(0.028 - i * 0.003, Vector3(randf_range(-0.5, 0.5), 0.62, randf_range(-0.2, 0.2)),
					white, root)
			office._box(Vector3(0.35, 0.02, 0.5), Vector3(0.95, 0.30, 0), wood, root, false)
			office._box(Vector3(0.28, 0.05, 0.35), Vector3(0.95, 0.34, 0),
				office._mat("sp_c_e0b4b8", Color.html("e0b4b8")), root, false)
		_:
			return false
	return true


## Fold a wrapper-created piece into the catalog root (strip its own
## registration so ids/persistence belong to the purchase, not a clone).
func _adopt(piece: Node3D, root: Node3D) -> void:
	if piece == null:
		return
	office.remove_child(piece)
	piece.position = Vector3.ZERO
	piece.remove_from_group("furniture")
	root.add_child(piece)


## Native-scale model (Kenney/KayKit kits are true-to-life meters) with
## a sanity clamp, optional shelf height and optional real light source.
func _spawn_glb(params: Dictionary, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(at.x, float(params.get("y", 0.0)), at.z)
	office.add_child(root)
	office._movable(root)
	var node: Node3D = office._instantiate_glb(str(params.get("model", "")))
	if node == null:
		root.queue_free()
		return null
	root.add_child(node)
	var aabb: AABB = office._combined_aabb(node, Transform3D.IDENTITY)
	var mx := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if mx > 3.5:
		node.scale = Vector3.ONE * (2.0 / mx)
	elif mx < 0.05 and mx > 0.0001:
		node.scale = Vector3.ONE * (0.4 / mx)
	if params.has("light"):
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, float(params["light"]), 0)
		lamp.light_color = Color(1.0, 0.87, 0.68)
		lamp.light_energy = 1.1
		lamp.omni_range = 3.5
		lamp.shadow_enabled = false
		root.add_child(lamp)
	return root


func _spawn_wall(params: Dictionary, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(at.x, 0, at.z)
	office.add_child(root)
	office._movable(root)
	root.add_to_group("wall_surface")
	root.set_meta("half_t", 0.06)
	var w := float(params.get("w", 2.0))
	root.set_meta("half_len", w / 2.0)
	var h := 1.15 if params.has("half") else 2.55
	var m: StandardMaterial3D
	if params.has("glass"):
		m = StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.84, 0.90, 0.26)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.05
		m.metallic = 0.1
	else:
		var wc := str(params.get("col", "ebe8e1"))
		m = office._mat("bwall_" + wc, Color.html(wc))
	office._box(Vector3(w, h, 0.09), Vector3(0, h / 2.0, 0), m, root, false)
	if params.has("glass"):    # slim posts so the pane reads at a glance
		var post: StandardMaterial3D = office._mat("bwall_post", Color(0.30, 0.31, 0.34))
		for px in [-w / 2.0, w / 2.0]:
			office._box(Vector3(0.05, h, 0.06), Vector3(px, h / 2.0, 0), post, root, false)
	return root


func _catalog_pick(kind: String, params: Dictionary) -> void:
	if carrying:
		cancel_carry()
	if kind == "floor":
		_paint = params        # paint mode: click a tile or drag a rect
		_wall_draw = {}
		_last_paint_cell = Vector2i(-9999, -9999)
		return
	if kind == "wall" or str(params.get("id", "")) in ["gwall", "slatwall", "glassframe", "fence"]:
		_paint = {}
		_wall_draw = {"kind": kind, "params": params}
		EventBus.log_line.emit(I18n.t("hint_walldraw"))
		return
	_paint = {}
	_wall_draw = {}
	var at := _floor_point(get_viewport().get_visible_rect().size * 0.5)
	var node := _spawn(kind, params, at)
	if node == null:
		return
	carrying = node
	_carry_new = true
	_carry_entry = {"kind": kind, "params": params}
	_carry_wall = int(params.get("wall", 0)) == 1
	_wall_ok = not _carry_wall
	if _carry_wall:
		node.set_meta("wall_item", true)
	# The Sims wall convention: wall runs live ON tile edges, columns on
	# corners — so pieces join cleanly and corners always meet
	_carry_snap = ""
	if kind == "wall" or str(params.get("id", "")) in ["slatwall", "glassframe", "fence", "gwall"]:
		_carry_snap = "edge"
	elif str(params.get("id", "")) == "column_p":
		_carry_snap = "corner"
	if not _carry_snap.is_empty():
		node.set_meta("snap_mode", _carry_snap)
	var ab2: AABB = office._combined_aabb(node, Transform3D.IDENTITY)
	_foot_size = Vector2(maxf(ab2.size.x, 0.3) + 0.12, maxf(ab2.size.z, 0.3) + 0.12)
	Sfx.play_ui("paper", -10.0)
	_attach_ring()
	_update_swatches()


func _record_added(piece: Node3D, entry: Dictionary) -> void:
	var layout := _load_layout()
	var added: Array = layout.get("added", [])
	var id := str(piece.get_meta("piece_id", ""))
	if not id.begins_with("a"):
		id = "a%03d" % _added_seq
		_added_seq += 1
		piece.set_meta("piece_id", id)
	var found := false
	for e in added:
		if str(e.get("id", "")) == id:
			e["x"] = piece.position.x
			e["z"] = piece.position.z
			e["rot"] = piece.rotation_degrees.y
			found = true
	if not found:
		added.append({"id": id, "kind": entry.get("kind", ""),
			"params": entry.get("params", {}),
			"x": piece.position.x, "z": piece.position.z,
			"rot": piece.rotation_degrees.y})
	layout["added"] = added
	_write_layout(layout)


func _save_move(piece: Node3D) -> void:
	var id := str(piece.get_meta("piece_id", ""))
	var layout := _load_layout()
	if id.begins_with("a"):         # owner-added piece moved again
		_record_added(piece, {})
		return
	var moved: Dictionary = layout.get("moved", {})
	moved[id] = {"x": piece.position.x, "z": piece.position.z,
		"rot": piece.rotation_degrees.y}
	layout["moved"] = moved
	_write_layout(layout)


# --------------------------------------------------------- persistence

func _load_layout() -> Dictionary:
	var path := _save_path()
	if not FileAccess.file_exists(path) and Config.office_branch == "studio" \
			and FileAccess.file_exists("user://furniture_layout.json"):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path("user://furniture_layout.json"),
			ProjectSettings.globalize_path(path))   # one-time migration
	if not FileAccess.file_exists(path):
		return {"moved": {}, "deleted": [], "added": [], "floors": {}}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		return {"moved": {}, "deleted": [], "added": [], "floors": {}}
	var dict: Dictionary = d
	if dict.has("moved") or dict.has("added") or dict.has("deleted") or dict.has("floors"):
		for k in ["moved", "floors"]:
			if not dict.has(k):
				dict[k] = {}
		for k in ["deleted", "added"]:
			if not dict.has(k):
				dict[k] = []
		return dict
	return {"moved": dict, "deleted": [], "added": [], "floors": {}}  # phase-1 file


## A junction post whose glass runs are ALL deleted has nothing left
## to hold up — it leaves with them (unless the owner moved it on
## purpose). Persisted like any deletion.
func _prune_posts(layout: Dictionary) -> void:
	var del: Array = layout.get("deleted", [])
	var moved: Dictionary = layout.get("moved", {})
	var changed := false
	for f in get_tree().get_nodes_in_group("furniture"):
		if not is_instance_valid(f) or not (f as Node).has_meta("runs"):
			continue
		var id := str((f as Node).get_meta("piece_id", ""))
		if del.has(id) or moved.has(id):
			continue
		var all_gone := true
		for rid in (f as Node).get_meta("runs"):
			if not del.has(str(rid)):
				all_gone = false
				break
		if all_gone:
			del.append(id)
			changed = true
			(f as Node).queue_free()
	if changed:
		layout["deleted"] = del
		_write_layout(layout)


var _layout_backed := false


func _write_layout(layout: Dictionary) -> void:
	# once per session: snapshot the previous save before touching it —
	# a fat-fingered wipe (mine, 2026-07-10) must never cost real work
	if not _layout_backed:
		_layout_backed = true
		var pth := _save_path()
		if FileAccess.file_exists(pth):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(pth),
				ProjectSettings.globalize_path(pth + ".bak"))
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(layout, "  "))


## Boot-time: re-apply the owner's whole layout — moves, deletions,
## purchases and floor paint (called by main once the office is built).
func apply_layout() -> void:
	var layout := _load_layout()
	var deleted: Array = layout.get("deleted", [])
	var moved: Dictionary = layout.get("moved", {})
	for f in get_tree().get_nodes_in_group("furniture"):
		var id := str((f as Node).get_meta("piece_id", ""))
		if deleted.has(id):
			(f as Node).queue_free()
			continue
		if moved.has(id):
			var e: Dictionary = moved[id]
			(f as Node3D).position.x = float(e.get("x", (f as Node3D).position.x))
			(f as Node3D).position.z = float(e.get("z", (f as Node3D).position.z))
			(f as Node3D).rotation_degrees.y = float(e.get("rot", 0.0))
	for e in layout.get("added", []):
		var node := _spawn(str(e.get("kind", "")), e.get("params", {}),
			Vector3(float(e.get("x", 0.0)), 0, float(e.get("z", 0.0))))
		if node:
			node.rotation_degrees.y = float(e.get("rot", 0.0))
			node.set_meta("piece_id", str(e.get("id", "")))
			if int(e.get("params", {}).get("wall", 0)) == 1:
				node.set_meta("wall_item", true)
			var n := int(str(e.get("id", "a0")).substr(1))
			_added_seq = maxi(_added_seq, n + 1)
	_prune_posts(layout)
	var floors: Dictionary = layout.get("floors", {})
	for key in floors:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if office.floor_tiles.has(cell):
			(office.floor_tiles[cell] as MeshInstance3D).material_override = \
				_floor_mat(floors[key])


# ------------------------------------------------------------------ UI

func _build_catalog_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 8
	_ui.visible = false
	add_child(_ui)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -278.0
	panel.offset_right = -16.0
	panel.offset_top = 72.0
	panel.custom_minimum_size = Vector2(262, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := Label.new()
	I18n.reg(title, "text", "build_catalog")
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	v.add_child(title)
	_cat_bar = HFlowContainer.new()
	_cat_bar.add_theme_constant_override("h_separation", 4)
	_cat_bar.add_theme_constant_override("v_separation", 4)
	v.add_child(_cat_bar)
	for i in _cats.size():
		var b := Button.new()
		I18n.reg(b, "text", str(_cats[i][0]))
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: _show_cat(i))
		_cat_bar.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(238, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	# THE SIMS DESIGN TOOL: while you hold a colourable piece, this
	# swatch bar repaints it in place (id, spot and rotation kept)
	_swatch_row = HBoxContainer.new()
	_swatch_row.add_theme_constant_override("separation", 4)
	_swatch_row.visible = false
	var sl := Label.new()
	I18n.reg(sl, "text", "pick_color")
	sl.add_theme_font_size_override("font_size", 12)
	_swatch_row.add_child(sl)
	for pc in PALETTE:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(17, 22)
		sw.focus_mode = Control.FOCUS_NONE
		var sbx := StyleBoxFlat.new()
		sbx.bg_color = Color.html(str(pc[1]))
		sbx.set_corner_radius_all(4)
		sw.add_theme_stylebox_override("normal", sbx)
		sw.add_theme_stylebox_override("hover", sbx)
		sw.add_theme_stylebox_override("pressed", sbx)
		sw.tooltip_text = str(pc[0])
		var hex: String = str(pc[1])
		sw.pressed.connect(func() -> void: _recolor(hex))
		_swatch_row.add_child(sw)
	v.add_child(_swatch_row)
	var hint := Label.new()
	I18n.reg(hint, "text", "build_keys")
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(238, 0)
	v.add_child(hint)
	_show_cat(0)


func _show_cat(idx: int) -> void:
	_cur_cat = idx
	_paint = {}
	for i in _cat_bar.get_child_count():
		(_cat_bar.get_child(i) as Button).button_pressed = (i == idx)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var items: Array = _cats[idx][1]
	for it in items:
		var names: Dictionary = it[0]
		var kind: String = it[1]
		var params: Dictionary = it[2]
		var b := Button.new()
		b.custom_minimum_size = Vector2(74, 74)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = str(names.get(I18n.lang, names.get("th", "?")))
		b.pressed.connect(func() -> void: _catalog_pick(kind, params))
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4.0
		tr.offset_top = 4.0
		tr.offset_right = -4.0
		tr.offset_bottom = -4.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.add_child(tr)
		b.set_meta("icon_rect", tr)
		_grid.add_child(b)
	_icon_gen += 1
	_fill_icons(idx, _icon_gen)


## The Sims sells with pictures: render each piece once from a 3/4
## angle into a tiny viewport, cache the texture, drop it on the card.
func _fill_icons(idx: int, gen: int) -> void:
	var items: Array = _cats[idx][1]
	for i in items.size():
		if gen != _icon_gen:
			return
		var it: Array = items[i]
		var tex: Texture2D = await _item_icon(str(it[1]), it[2])
		if gen != _icon_gen or tex == null or i >= _grid.get_child_count():
			continue
		var b := _grid.get_child(i) as Button
		var tr := b.get_meta("icon_rect") as TextureRect
		if tr:
			tr.texture = tex


func _item_icon(kind: String, params: Dictionary) -> Texture2D:
	var key := kind + JSON.stringify(params)
	if _icon_cache.has(key):
		return _icon_cache[key]
	if office == null:
		return null
	_ensure_vp()
	var node: Node3D
	if kind == "floor":            # flat swatch tile, slight angle
		node = Node3D.new()
		_vp_root.add_child(node)
		office._box(Vector3(0.9, 0.06, 0.9), Vector3(0, 0.03, 0), _floor_mat(params), node, false)
	else:
		var seq: int = office._piece_seq
		node = _spawn(kind, params, Vector3.ZERO)
		office._piece_seq = seq      # icon models must not eat piece ids
		if node == null:
			return null
		node.remove_from_group("furniture")
		node.get_parent().remove_child(node)
		_vp_root.add_child(node)
		node.position = Vector3.ZERO
		node.rotation_degrees = Vector3.ZERO
	var aabb: AABB = office._combined_aabb(node, Transform3D.IDENTITY)
	var c := aabb.get_center()
	var r: float = maxf(aabb.size.length() * 0.5, 0.18)
	_vp_cam.look_at_from_position(c + Vector3(1.0, 0.85, 1.0).normalized() * r * 3.9, c)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	node.queue_free()
	# autocrop to the drawn pixels so the piece FILLS its card (no dead
	# margins, nothing cut off — framing is exact regardless of shape)
	var used := img.get_used_rect()
	if used.size.x > 4 and used.size.y > 4:
		img = img.get_region(used.grow(3).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex


func _ensure_vp() -> void:
	if _vp:
		return
	_vp = SubViewport.new()
	_vp.size = Vector2i(160, 160)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_vp_cam = Camera3D.new()
	_vp_cam.fov = 30.0
	_vp.add_child(_vp_cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 142, 0)
	fill.light_energy = 0.55
	_vp.add_child(fill)
	_vp_root = Node3D.new()
	_vp.add_child(_vp_root)
