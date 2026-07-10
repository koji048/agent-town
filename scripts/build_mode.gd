## BUILD MODE (The Sims): a full categorized catalog — seating, tables,
## storage, lighting, plants, decor, gadgets, FLOOR PAINT and WALLS.
## Click a card to spawn+carry (R rotate, X delete, Esc cancel), click a
## floor style then paint tiles one click at a time. Existing furniture
## can be picked up too. Everything persists to user:// and is re-applied
## on boot: moved pieces, deletions, purchases, painted floors.
class_name BuildMode
extends Node

const SAVE_PATH := "user://furniture_layout.json"
const SNAP := 0.25

## kinds: chair/sofa/armchair/shelf = procedural office builders,
## prop = Office3D._prop (normalized fit), glb = native-scale model,
## wall = procedural partition, floor = tile paint style.
const CATALOG := [
	["cat_seat", [
		[{"th": "เก้าอี้ทำงาน", "en": "Task chair"}, "chair", {}],
		[{"th": "โซฟาเทา", "en": "Sofa gray"}, "sofa", {"col": "8c8a87"}],
		[{"th": "โซฟาเขียวเสจ", "en": "Sofa sage"}, "sofa", {"col": "9eab91"}],
		[{"th": "อาร์มแชร์น้ำเงิน", "en": "Armchair blue"}, "armchair", {"col": "4d619e"}],
		[{"th": "อาร์มแชร์อิฐ", "en": "Armchair clay"}, "armchair", {"col": "cc8266"}],
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
		[{"th": "โซฟากรมท่า", "en": "Sofa navy"}, "sofa", {"col": "33415e"}],
		[{"th": "โซฟามัสตาร์ด", "en": "Sofa mustard"}, "sofa", {"col": "cfa63f"}],
		[{"th": "โซฟาชมพู", "en": "Sofa blush"}, "sofa", {"col": "e0b4b8"}],
		[{"th": "โซฟาดำ", "en": "Sofa black"}, "sofa", {"col": "2b2c30"}],
		[{"th": "อาร์มแชร์เขียว", "en": "Armchair green"}, "armchair", {"col": "5f7a5a"}],
		[{"th": "อาร์มแชร์เทา", "en": "Armchair gray"}, "armchair", {"col": "8c8a87"}],
		[{"th": "อาร์มแชร์มัสตาร์ด", "en": "Armchair mustard"}, "armchair", {"col": "cfa63f"}],
		[{"th": "เก้าอี้คาเฟ่ม่วง", "en": "Cafe chair purple"}, "special", {"id": "cafe_chair", "col": "8f6bb0"}],
		[{"th": "เก้าอี้คาเฟ่แดง", "en": "Cafe chair red"}, "special", {"id": "cafe_chair", "col": "c14b3f"}],
		[{"th": "บีนแบ็กเทา", "en": "Beanbag gray"}, "special", {"id": "beanbag", "col": "7d7f83"}],
		[{"th": "บีนแบ็กเขียว", "en": "Beanbag green"}, "special", {"id": "beanbag", "col": "5f7a5a"}],
		[{"th": "บีนแบ็กส้ม", "en": "Beanbag orange"}, "special", {"id": "beanbag", "col": "d96c33"}],
		[{"th": "ออตโตมันครีม", "en": "Ottoman cream"}, "special", {"id": "ottoman", "col": "d9cbb0"}],
		[{"th": "ออตโตมันเทียล", "en": "Ottoman teal"}, "special", {"id": "ottoman", "col": "2a7f86"}],
		[{"th": "ออตโตมันชมพู", "en": "Ottoman blush"}, "special", {"id": "ottoman", "col": "e0b4b8"}],
		[{"th": "ม้านั่งไม้", "en": "Wood bench"}, "special", {"id": "bench_wood"}],
		[{"th": "โซฟาตัว L เทา", "en": "L-sofa gray"}, "special", {"id": "sofa_l", "col": "8c8a87"}],
		[{"th": "โซฟาตัว L เขียว", "en": "L-sofa green"}, "special", {"id": "sofa_l", "col": "5f7a5a"}],
		[{"th": "สตูลกลมชมพู", "en": "Round stool blush"}, "special", {"id": "stool_round", "col": "e0b4b8"}],
		[{"th": "สตูลกลมดำ", "en": "Round stool black"}, "special", {"id": "stool_round", "col": "2b2c30"}],
		[{"th": "เก้าอี้ปีกกรมท่า", "en": "Wingback navy"}, "special", {"id": "wing", "col": "33415e"}],
		[{"th": "เก้าอี้ปีกอิฐ", "en": "Wingback clay"}, "special", {"id": "wing", "col": "b3705c"}],
	]],
	["cat_table", [
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
		[{"th": "โต๊ะตัว L ขาว", "en": "L-desk white"}, "special", {"id": "desk_l", "col": "f0ede6"}],
		[{"th": "โต๊ะตัว L ไม้", "en": "L-desk wood"}, "special", {"id": "desk_l", "col": "b08a5e"}],
		[{"th": "โต๊ะกระจก", "en": "Glass desk"}, "special", {"id": "desk_glass"}],
		[{"th": "โต๊ะผู้บริหาร", "en": "Executive desk"}, "special", {"id": "desk_exec"}],
		[{"th": "โต๊ะปิกนิก", "en": "Picnic table"}, "special", {"id": "picnic"}],
		[{"th": "โต๊ะบาร์สูงไม้", "en": "Bar table wood"}, "special", {"id": "table_bar", "col": "b08a5e"}],
		[{"th": "โต๊ะบาร์สูงดำ", "en": "Bar table black"}, "special", {"id": "table_bar", "col": "2b2c30"}],
		[{"th": "โต๊ะกาแฟวงรีไม้", "en": "Oval coffee wood"}, "special", {"id": "coffee_oval", "col": "b08a5e"}],
		[{"th": "โต๊ะกาแฟวงรีขาว", "en": "Oval coffee white"}, "special", {"id": "coffee_oval", "col": "f0ede6"}],
		[{"th": "โต๊ะลูกบาศก์ขาว", "en": "Cube table white"}, "special", {"id": "side_cube", "col": "f0ede6"}],
		[{"th": "โต๊ะลูกบาศก์ดำ", "en": "Cube table black"}, "special", {"id": "side_cube", "col": "26272b"}],
		[{"th": "โต๊ะพับ", "en": "Folding table"}, "special", {"id": "folding"}],
	]],
	["cat_store", [
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
		[{"th": "ตู้เอกสาร 2 ลิ้นชัก", "en": "File cabinet 2"}, "special", {"id": "file_cab", "n": 2, "col": "9b9c9a"}],
		[{"th": "ตู้เอกสาร 4 ลิ้นชัก", "en": "File cabinet 4"}, "special", {"id": "file_cab", "n": 4, "col": "9b9c9a"}],
		[{"th": "ตู้เอกสารดำ", "en": "File cabinet black"}, "special", {"id": "file_cab", "n": 4, "col": "2b2c30"}],
		[{"th": "ตู้เสื้อผ้าขาว", "en": "Wardrobe white"}, "special", {"id": "wardrobe", "col": "f0ede6"}],
		[{"th": "ตู้เสื้อผ้าไม้", "en": "Wardrobe wood"}, "special", {"id": "wardrobe", "col": "b08a5e"}],
		[{"th": "ตู้เซฟ", "en": "Safe"}, "special", {"id": "safe"}],
		[{"th": "ชั้นลอยติดผนัง", "en": "Wall shelf"}, "special", {"id": "shelf_wall", "y": 1.4}],
		[{"th": "กองลังไม้", "en": "Crate stack"}, "special", {"id": "crate_stack"}],
		[{"th": "ชั้นพิงผนังไม้", "en": "Ladder shelf wood"}, "special", {"id": "shelf_ladder", "col": "b08a5e"}],
		[{"th": "ชั้นพิงผนังดำ", "en": "Ladder shelf black"}, "special", {"id": "shelf_ladder", "col": "26272b"}],
		[{"th": "กล่องพลาสติกฟ้า", "en": "Plastic box blue"}, "special", {"id": "box_plastic", "col": "7da7c9"}],
		[{"th": "กล่องพลาสติกเทา", "en": "Plastic box gray"}, "special", {"id": "box_plastic", "col": "9b9c9a"}],
		[{"th": "ชั้นท่ออุตสาหกรรม", "en": "Pipe shelf"}, "special", {"id": "shelf_pipe"}],
		[{"th": "รถเข็นชั้นวาง", "en": "Utility cart"}, "special", {"id": "cart_roll"}],
		[{"th": "ล็อกเกอร์เขียวเสจ", "en": "Lockers sage"}, "special", {"id": "locker", "col": "9eab91"}],
		[{"th": "ล็อกเกอร์แดงอิฐ", "en": "Lockers clay"}, "special", {"id": "locker", "col": "b3705c"}],
	]],
	["cat_light", [
		[{"th": "โคมตั้งพื้นกลม", "en": "Floor lamp"}, "glb", {"model": "lampRoundFloor", "light": 1.4}],
		[{"th": "โคมตั้งพื้นสูง", "en": "Standing lamp"}, "glb", {"model": "kaykit/lamp_standing", "light": 1.5}],
		[{"th": "โคมโต๊ะเหลี่ยม", "en": "Table lamp"}, "glb", {"model": "lampSquareTable", "light": 0.5, "y": 0.74}],
		[{"th": "โคมโต๊ะ", "en": "Desk lamp"}, "glb", {"model": "kaykit/lamp_table", "light": 0.5, "y": 0.74}],
		[{"th": "ไฟห้อยดำ", "en": "Pendant black"}, "special", {"id": "pendant", "col": "26272b"}],
		[{"th": "ไฟห้อยทอง", "en": "Pendant gold"}, "special", {"id": "pendant", "col": "c9a13b"}],
		[{"th": "ไฟห้อยขาว", "en": "Pendant white"}, "special", {"id": "pendant", "col": "f0ede6"}],
		[{"th": "นีออนชมพู", "en": "Neon pink"}, "special", {"id": "neon_strip", "col": "e84393", "y": 1.4}],
		[{"th": "นีออนฟ้า", "en": "Neon blue"}, "special", {"id": "neon_strip", "col": "3fb8d9", "y": 1.4}],
		[{"th": "นีออนเหลือง", "en": "Neon yellow"}, "special", {"id": "neon_strip", "col": "e8c93f", "y": 1.4}],
		[{"th": "ไฟราวเฟสตูน", "en": "String lights"}, "special", {"id": "string_lights"}],
		[{"th": "โคมโค้งตั้งพื้น", "en": "Arc lamp"}, "special", {"id": "lamp_arc"}],
		[{"th": "โคมสามขา", "en": "Tripod lamp"}, "special", {"id": "lamp_tripod"}],
		[{"th": "โคมแขนพับดำ", "en": "Task lamp black"}, "special", {"id": "lamp_arm", "col": "26272b", "y": 0.74}],
		[{"th": "โคมแขนพับขาว", "en": "Task lamp white"}, "special", {"id": "lamp_arm", "col": "f0ede6", "y": 0.74}],
		[{"th": "โคมกระดาษเล็ก", "en": "Lantern small"}, "special", {"id": "lantern", "s": 0.16}],
		[{"th": "โคมกระดาษใหญ่", "en": "Lantern big"}, "special", {"id": "lantern", "s": 0.26}],
		[{"th": "ซอฟต์บ็อกซ์", "en": "Softbox"}, "special", {"id": "softbox"}],
		[{"th": "ริงไลท์", "en": "Ring light"}, "special", {"id": "ring_light"}],
		[{"th": "โคมเห็ดส้ม", "en": "Mushroom orange"}, "special", {"id": "lamp_mushroom", "col": "d96c33", "y": 0.74}],
		[{"th": "โคมเห็ดเขียว", "en": "Mushroom green"}, "special", {"id": "lamp_mushroom", "col": "5f7a5a", "y": 0.74}],
		[{"th": "ชุดเทียน", "en": "Candles"}, "special", {"id": "candles", "y": 0.74}],
		[{"th": "โคมแบงเกอร์", "en": "Banker lamp"}, "special", {"id": "banker", "y": 0.74}],
	]],
	["cat_plant", [
		[{"th": "ต้นไม้กระถาง", "en": "Potted plant"}, "prop", {"model": "pottedPlant", "fit_h": 1.15}],
		[{"th": "ไม้กระถางเล็ก 1", "en": "Small plant 1"}, "glb", {"model": "plantSmall1"}],
		[{"th": "ไม้กระถางเล็ก 2", "en": "Small plant 2"}, "glb", {"model": "plantSmall2"}],
		[{"th": "ไม้แขวน", "en": "Hanging plant"}, "glb", {"model": "plantSmall3"}],
		[{"th": "กระบองเพชรเล็ก", "en": "Small cactus"}, "prop", {"model": "kaykit/cactus_small_A", "fit_h": 0.42}],
		[{"th": "กระบองเพชรกลาง", "en": "Cactus"}, "prop", {"model": "kaykit/cactus_medium_A", "fit_h": 0.6}],
		[{"th": "มอนสเตอร่า", "en": "Monstera"}, "special", {"id": "monstera"}],
		[{"th": "ปาล์มกระถาง", "en": "Palm"}, "special", {"id": "palm"}],
		[{"th": "ไทรใบสัก", "en": "Ficus"}, "special", {"id": "ficus"}],
		[{"th": "ลิ้นมังกร", "en": "Snake plant"}, "special", {"id": "snake_plant"}],
		[{"th": "เฟิร์นแขวน", "en": "Hanging fern"}, "special", {"id": "fern_hang", "y": 1.9}],
		[{"th": "ไผ่กวนอิม", "en": "Bamboo"}, "special", {"id": "bamboo"}],
		[{"th": "ต้นไม้ใหญ่ในอาคาร", "en": "Big indoor tree"}, "special", {"id": "bigtree"}],
		[{"th": "กระบะต้นไม้ยาว", "en": "Long planter"}, "special", {"id": "planter_long"}],
		[{"th": "บอนไซ", "en": "Bonsai"}, "special", {"id": "bonsai", "y": 0.74}],
		[{"th": "แจกันดอกไม้แดง", "en": "Vase red"}, "special", {"id": "vase", "col": "c14b3f", "y": 0.74}],
		[{"th": "แจกันดอกไม้เหลือง", "en": "Vase yellow"}, "special", {"id": "vase", "col": "e8c93f", "y": 0.74}],
		[{"th": "แจกันดอกไม้ฟ้า", "en": "Vase blue"}, "special", {"id": "vase", "col": "7da7c9", "y": 0.74}],
		[{"th": "สมุนไพรครัว", "en": "Herb set"}, "special", {"id": "herbs", "y": 0.74}],
		[{"th": "สวนแนวตั้ง", "en": "Green wall"}, "special", {"id": "mosswall", "y": 1.2}],
		[{"th": "กระบองเพชรยักษ์", "en": "Saguaro"}, "special", {"id": "saguaro"}],
		[{"th": "หญ้าแพมพาส", "en": "Pampas"}, "special", {"id": "pampas"}],
		[{"th": "พลูด่างกระถาง", "en": "Pothos"}, "special", {"id": "pothos", "y": 0.74}],
	]],
	["cat_decor", [
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
	]],
	["cat_gear", [
		[{"th": "แล็ปท็อป", "en": "Laptop"}, "prop", {"model": "laptop", "fit": 0.32, "y": 0.74}],
		[{"th": "จอคอม", "en": "Monitor"}, "prop", {"model": "computerScreen", "fit_h": 0.38, "y": 0.74}],
		[{"th": "คีย์บอร์ด", "en": "Keyboard"}, "prop", {"model": "computerKeyboard", "fit": 0.28, "y": 0.74}],
		[{"th": "เมาส์", "en": "Mouse"}, "glb", {"model": "computerMouse", "y": 0.74}],
		[{"th": "ทีวีจอแบน", "en": "Television"}, "glb", {"model": "televisionModern", "y": 0.5}],
		[{"th": "ลำโพงตั้งพื้น", "en": "Speaker"}, "glb", {"model": "speaker"}],
		[{"th": "เครื่องชงกาแฟ", "en": "Coffee machine"}, "glb", {"model": "kitchenCoffeeMachine", "y": 0.9}],
		[{"th": "ตู้เย็นเล็ก", "en": "Small fridge"}, "glb", {"model": "kitchenFridgeSmall"}],
	]],
	["cat_office", [
		[{"th": "โต๊ะปรับยืน", "en": "Standing desk"}, "special", {"id": "desk_stand"}],
		[{"th": "บูธเงียบ", "en": "Focus booth"}, "special", {"id": "booth"}],
		[{"th": "ตู้กดน้ำ", "en": "Water cooler"}, "special", {"id": "cooler"}],
		[{"th": "ตู้ขายของ", "en": "Vending machine"}, "special", {"id": "vending"}],
		[{"th": "เครื่องถ่ายเอกสาร", "en": "Copier"}, "special", {"id": "copier"}],
		[{"th": "ไวท์บอร์ดล้อเลื่อน", "en": "Whiteboard"}, "special", {"id": "wboard"}],
		[{"th": "ตู้ล็อกเกอร์", "en": "Lockers"}, "special", {"id": "locker"}],
		[{"th": "โต๊ะประชุม", "en": "Conference table"}, "special", {"id": "conftable"}],
		[{"th": "ตู้ถ้วยรางวัล", "en": "Trophy case"}, "special", {"id": "trophy"}],
		[{"th": "โต๊ะปิงปอง", "en": "Ping-pong table"}, "special", {"id": "pingpong"}],
		[{"th": "ตู้เซิร์ฟเวอร์", "en": "Server rack"}, "special", {"id": "server"}],
		[{"th": "นาฬิกาตั้งพื้น", "en": "Standing clock"}, "special", {"id": "clock"}],
	]],
	["cat_scandi", [
		[{"th": "โต๊ะขาวมินิมอล", "en": "Frame desk"}, "special", {"id": "desk_scandi"}],
		[{"th": "ตู้ลิ้นชัก 7 ชั้น", "en": "7-drawer unit"}, "special", {"id": "drawer7"}],
		[{"th": "เก้าอี้หมุนไม้อ่อน", "en": "Swivel chair"}, "special", {"id": "chair_scandi"}],
		[{"th": "ไซด์บอร์ดขาว", "en": "Sideboard"}, "special", {"id": "sideboard"}],
		[{"th": "นาฬิกาแขวน", "en": "Wall clock"}, "special", {"id": "wallclock", "y": 1.45}],
		[{"th": "กระดานดำกรอบไม้", "en": "Chalkboard"}, "special", {"id": "chalkboard"}],
		[{"th": "บอร์ดหมุดโน้ต", "en": "Pinboard"}, "special", {"id": "corkboard"}],
		[{"th": "นาฬิกา Flip", "en": "Flip clock"}, "special", {"id": "flipclock", "y": 0.74}],
		[{"th": "ที่ใส่แม็กกาซีน", "en": "Magazine files"}, "special", {"id": "magfiles", "y": 0.74}],
		[{"th": "ทิวลิปกระถาง", "en": "Tulip pot"}, "special", {"id": "tulip", "y": 0.74}],
		[{"th": "ตะกร้าผ้า", "en": "Fabric basket"}, "special", {"id": "basket"}],
		[{"th": "ลูกโลก", "en": "Globe"}, "special", {"id": "globe", "y": 0.74}],
		[{"th": "ปรินเตอร์", "en": "Printer"}, "special", {"id": "printer", "y": 0.74}],
		[{"th": "โต๊ะกลมทิวลิป", "en": "Tulip table"}, "special", {"id": "tulip_table"}],
		[{"th": "เก้าอี้คาเฟ่เหลือง", "en": "Cafe chair yellow"}, "special", {"id": "cafe_chair", "col": "d9b23a"}],
		[{"th": "เก้าอี้คาเฟ่เขียว", "en": "Cafe chair green"}, "special", {"id": "cafe_chair", "col": "3aa06c"}],
		[{"th": "เก้าอี้คาเฟ่ส้ม", "en": "Cafe chair orange"}, "special", {"id": "cafe_chair", "col": "d96c33"}],
		[{"th": "เก้าอี้คาเฟ่เทียล", "en": "Cafe chair teal"}, "special", {"id": "cafe_chair", "col": "2a7f86"}],
		[{"th": "ฉากกั้นตะแกรง", "en": "Grid divider"}, "special", {"id": "griddiv"}],
		[{"th": "โปสเตอร์เทียล", "en": "Poster teal"}, "special", {"id": "poster", "col": "2a9d8f", "y": 1.25}],
		[{"th": "โปสเตอร์ครีม", "en": "Poster tan"}, "special", {"id": "poster", "col": "c9a074", "y": 1.25}],
		[{"th": "โต๊ะข้างทรงกลอง", "en": "Drum table"}, "special", {"id": "drumtable"}],
	]],
	["cat_special", [
		[{"th": "เตียงนอน", "en": "Double bed"}, "special", {"id": "bed"}],
		[{"th": "แกรนด์เปียโน", "en": "Grand piano"}, "special", {"id": "piano"}],
		[{"th": "เตาผิง", "en": "Fireplace"}, "special", {"id": "fireplace"}],
		[{"th": "ตู้ปลา", "en": "Aquarium"}, "special", {"id": "aquarium"}],
		[{"th": "โคมลาวา", "en": "Lava lamp"}, "special", {"id": "lava", "y": 0.74}],
		[{"th": "ทีวีย้อนยุค", "en": "Retro TV"}, "special", {"id": "crt"}],
		[{"th": "โต๊ะพูล", "en": "Pool table"}, "special", {"id": "pool"}],
		[{"th": "ตู้เพลง", "en": "Jukebox"}, "special", {"id": "jukebox"}],
		[{"th": "ชิงช้า", "en": "Swing set"}, "special", {"id": "swing"}],
		[{"th": "อ่างน้ำร้อน", "en": "Hot tub"}, "special", {"id": "hottub"}],
	]],
	["cat_floor", [
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
		[{"th": "ผนังทึบ 2 ม.", "en": "Wall 2m"}, "wall", {"w": 2.0}],
		[{"th": "ผนังทึบ 1 ม.", "en": "Wall 1m"}, "wall", {"w": 1.0}],
		[{"th": "ผนังครึ่ง 2 ม.", "en": "Half wall 2m"}, "wall", {"w": 2.0, "half": 1}],
		[{"th": "กระจกกั้น 2 ม.", "en": "Glass 2m"}, "wall", {"w": 2.0, "glass": 1}],
		[{"th": "กระจกกั้น 1 ม.", "en": "Glass 1m"}, "wall", {"w": 1.0, "glass": 1}],
		[{"th": "ผนังขาว", "en": "Wall white"}, "wall", {"w": 2.0, "col": "f0ede6"}],
		[{"th": "ผนังครีม", "en": "Wall cream"}, "wall", {"w": 2.0, "col": "e8dfc9"}],
		[{"th": "ผนังเทา", "en": "Wall gray"}, "wall", {"w": 2.0, "col": "9b9c9a"}],
		[{"th": "ผนังดำ", "en": "Wall black"}, "wall", {"w": 2.0, "col": "26272b"}],
		[{"th": "ผนังเขียวเสจ", "en": "Wall sage"}, "wall", {"w": 2.0, "col": "9eab91"}],
		[{"th": "ผนังกรมท่า", "en": "Wall navy"}, "wall", {"w": 2.0, "col": "33415e"}],
		[{"th": "ผนังเทอร์รา", "en": "Wall terracotta"}, "wall", {"w": 2.0, "col": "c17a5f"}],
		[{"th": "ผนังมัสตาร์ด", "en": "Wall mustard"}, "wall", {"w": 2.0, "col": "cfa63f"}],
		[{"th": "ผนังอิฐ", "en": "Wall brick"}, "wall", {"w": 2.0, "col": "9c4a35"}],
		[{"th": "ครึ่งผนังขาว", "en": "Half white"}, "wall", {"w": 2.0, "half": 1, "col": "f0ede6"}],
		[{"th": "ครึ่งผนังเสจ", "en": "Half sage"}, "wall", {"w": 2.0, "half": 1, "col": "9eab91"}],
		[{"th": "ครึ่งผนังกรม", "en": "Half navy"}, "wall", {"w": 2.0, "half": 1, "col": "33415e"}],
		[{"th": "ระแนงไม้", "en": "Wood slats"}, "special", {"id": "slatwall", "col": "b08a5e"}],
		[{"th": "ระแนงดำ", "en": "Black slats"}, "special", {"id": "slatwall", "col": "26272b"}],
		[{"th": "กระจกกรอบดำ 2 ม.", "en": "Framed glass 2m"}, "special", {"id": "glassframe", "w": 2.0}],
		[{"th": "กระจกกรอบดำ 1 ม.", "en": "Framed glass 1m"}, "special", {"id": "glassframe", "w": 1.0}],
		[{"th": "เสากลมขาว", "en": "Column white"}, "special", {"id": "column_p", "col": "f0ede6"}],
		[{"th": "เสากลมดำ", "en": "Column black"}, "special", {"id": "column_p", "col": "26272b"}],
		[{"th": "รั้วเตี้ยขาว", "en": "Low fence white"}, "special", {"id": "fence", "col": "f0ede6"}],
		[{"th": "รั้วเตี้ยดำ", "en": "Low fence black"}, "special", {"id": "fence", "col": "26272b"}],
	]],
]

var cam: Camera3D
var office: Node3D
var active := false
var carrying: Node3D = null
var _carry_new := false          # spawned from catalog, not placed yet
var _carry_entry := {}           # pending catalog entry {kind, params}
var _paint := {}                 # active floor style ({} = off)
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
	_build_catalog_ui()


func toggle() -> void:
	if active and carrying:
		cancel_carry()
	_paint = {}
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
	if not _paint.is_empty():
		_paint_tile(p)
		return true
	var best: Node3D = null
	var bd := 0.9
	for f in get_tree().get_nodes_in_group("furniture"):
		var fp := (f as Node3D).global_position
		var d := Vector2(fp.x - p.x, fp.z - p.z).length()
		if d < bd:
			bd = d
			best = f
	if best:
		_pick(best)
	return true


func handle_key(keycode: int) -> bool:
	if not active:
		return false
	if keycode == KEY_ESCAPE and not _paint.is_empty():
		_paint = {}
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
	if not active or carrying == null or cam == null:
		return
	var p := _floor_point(get_viewport().get_mouse_position())
	carrying.position.x = snappedf(p.x, SNAP)
	carrying.position.z = snappedf(p.z, SNAP)


# ---------------------------------------------------------------- carry

func _pick(piece: Node3D) -> void:
	carrying = piece
	_carry_new = false
	_carry_entry = {}
	_orig = piece.transform
	Sfx.play_ui("paper", -10.0)
	_attach_ring()


func _place() -> void:
	if _carry_new:
		_record_added(carrying, _carry_entry)
	else:
		_save_move(carrying)
	_drop_ring()
	Sfx.play_ui("chair", -8.0)
	carrying = null
	_carry_new = false
	_carry_entry = {}


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
	_drop_ring()
	Sfx.play_ui("paper", -12.0)
	carrying = null
	_carry_new = false
	_carry_entry = {}


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


# ----------------------------------------------------------- floor paint

func _paint_tile(p: Vector3) -> void:
	var cell := Vector2i(int(floorf(p.x / office.CELL)), int(floorf(p.z / office.CELL)))
	if not office.floor_tiles.has(cell):
		return
	var mi := office.floor_tiles[cell] as MeshInstance3D
	mi.material_override = _floor_mat(_paint)
	Sfx.play_ui("paper", -14.0)
	var layout := _load_layout()
	var floors: Dictionary = layout.get("floors", {})
	floors["%d,%d" % [cell.x, cell.y]] = _paint
	layout["floors"] = floors
	_write_layout(layout)


func _floor_mat(style: Dictionary) -> StandardMaterial3D:
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
			var felt: StandardMaterial3D = office._mat("sp_felt", Color(0.15, 0.45, 0.28))
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
			_cyl(0.16, 0.12, 0.28, Vector3(0, 0.14, 0), pot, root)
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
			_cyl(0.17, 0.13, 0.30, Vector3(0, 0.15, 0), white, root)
			_cyl(0.03, 0.045, 0.60, Vector3(0, 0.58, 0), dwood, root)
			_sph(0.26, Vector3(0, 1.05, 0), green, root)
			_sph(0.20, Vector3(0.14, 1.25, 0.05), dgreen, root)
			_sph(0.16, Vector3(-0.15, 1.22, -0.05), green, root)
		"snake_plant":
			_cyl(0.13, 0.10, 0.22, Vector3(0, 0.11, 0), white, root)
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
			office._box(Vector3(2.00, 0.06, 0.10), Vector3(0, 0.03, 0), dwood, root, false)
			office._box(Vector3(2.00, 0.06, 0.10), Vector3(0, 2.30, 0), dwood, root, false)
			for i in 13:
				office._box(Vector3(0.07, 2.25, 0.05), Vector3(-0.93 + i * 0.155, 1.16, 0),
					pm, root, false)
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
			for rz2 in [0.30, 0.75]:
				office._box(Vector3(1.80, 0.05, 0.04), Vector3(0, rz2, 0), pm, root, false)
			for i in 5:
				office._box(Vector3(0.05, 0.90, 0.05), Vector3(-0.80 + i * 0.40, 0.45, 0),
					pm, root, false)
		_:
			return false
	return true


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
	var w := float(params.get("w", 2.0))
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
		_paint = params        # enter paint mode: click tiles to repaint
		return
	_paint = {}
	var at := _floor_point(get_viewport().get_visible_rect().size * 0.5)
	var node := _spawn(kind, params, at)
	if node == null:
		return
	carrying = node
	_carry_new = true
	_carry_entry = {"kind": kind, "params": params}
	Sfx.play_ui("paper", -10.0)
	_attach_ring()


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

static func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"moved": {}, "deleted": [], "added": [], "floors": {}}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
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


static func _write_layout(layout: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
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
			var n := int(str(e.get("id", "a0")).substr(1))
			_added_seq = maxi(_added_seq, n + 1)
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
	for i in CATALOG.size():
		var b := Button.new()
		I18n.reg(b, "text", str(CATALOG[i][0]))
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
	var items: Array = CATALOG[idx][1]
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
	var items: Array = CATALOG[idx][1]
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
