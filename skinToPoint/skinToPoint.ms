-- skinToPoint.ms — standalone tool
-- Two skin-related tools and a small rollout that wires them together:
--   SkinToPointTool — walks the rig hierarchy from root and creates Point
--     helpers mirroring the source structure (with convention styling).
--   SkinSaveTool    — renames Skin-bearing meshes with a "skin_" prefix and
--     saves each Skin modifier's envelope (.env) next to the .max file.

struct SkinToPointTool
(
	prefix = "pt_",
	rootOverride = undefined,
	copyRotation = true,

	fn classifyBone name =
	(
		local lc = toLower name
		if lc == "root" then        #((color 153 228 214), 10, true)
		else if lc == "pelvis" then #((color 14 255 2),    15, true)
		else if lc == "attach" then #((color 28 28 177),   7,  false)
		else if lc == "camera" then #((color 166 229 229), 20, true)
		else if matchPattern lc pattern:"weapon_*" then #((color 8 8 136),    10, false)
		else if matchPattern lc pattern:"ik_hand*" then #((color 88 88 225),  3,  false)
		else if matchPattern lc pattern:"ik_foot*" then #((color 225 88 199), 3,  false)
		else if (findString lc "_twist_") != undefined or \
				(findString lc "_elbow_") != undefined or \
				(findString lc "_knee_") != undefined then
			#((color 224 86 86), 4, true)
		else if (matchPattern lc pattern:"thumb_*") or \
				(matchPattern lc pattern:"index_*") or \
				(matchPattern lc pattern:"middle_*") or \
				(matchPattern lc pattern:"ring_*") or \
				(matchPattern lc pattern:"pinky_*") then
			#((color 14 255 2), 2, true)
		else
			#((color 14 255 2), 5, true)
	),

	fn ancestorOf n =
	(
		local top = n
		while top.parent != undefined do top = top.parent
		top
	),

	fn isAlwaysClassified name =
	(
		local lc = toLower name
		lc == "root" or lc == "attach" or lc == "camera" or \
		(matchPattern lc pattern:"weapon_*") or \
		(matchPattern lc pattern:"ik_hand*") or \
		(matchPattern lc pattern:"ik_foot*")
	),

	fn isFacial name =
	(
		(findString (toLower name) "facial") != undefined
	),

	fn gatherAllSkinBones =
	(
		local bones = #()
		for n in objects do
		(
			for m in n.modifiers where (classOf m) == Skin do
			(
				local cnt = 0
				try ( cnt = skinOps.GetNumberBones m ) catch ()
				for i = 1 to cnt do
				(
					local boneName = ""
					try ( boneName = skinOps.GetBoneName m i 0 ) catch ()
					if boneName != "" do
					(
						local boneNode = getNodeByName boneName exact:true
						if boneNode != undefined and (findItem bones boneNode) == 0 do
							append bones boneNode
					)
				)
			)
		)
		bones
	),

	fn findRootFromSkin =
	(
		for n in objects do
		(
			for m in n.modifiers where (classOf m) == Skin do
			(
				local boneCount = 0
				try ( boneCount = skinOps.GetNumberBones m ) catch ()
				if boneCount > 0 do
				(
					local boneName = ""
					try ( boneName = skinOps.GetBoneName m 1 0 ) catch ()
					if boneName != "" do
					(
						local boneNode = getNodeByName boneName exact:true
						if boneNode != undefined do return (ancestorOf boneNode)
					)
				)
			)
		)
		undefined
	),

	fn findRoot =
	(
		if rootOverride != undefined then rootOverride
		else if selection.count > 0 then selection[1]
		else
		(
			local r = getNodeByName "root" exact:true
			if r != undefined then r else findRootFromSkin()
		)
	),

	fn gatherDescendants n =
	(
		local result = #(n)
		for child in n.children do
			join result (gatherDescendants child)
		result
	),

	-- Returns #(createdCount, reusedCount, totalBones, bones, pairs).
	fn run =
	(
		local root = findRoot()
		if root == undefined then
		(
			messageBox "No root bone found.\nSelect a root node, or have a 'root' node, or a Skin-influenced mesh in the scene." title:"Skin -> Point"
			return #(0, 0, 0, #(), #())
		)

		local bones = gatherDescendants root
		local skinBones = gatherAllSkinBones()
		local createdCount = 0
		local reusedCount = 0
		local pairs = #()

		undo "Skin Bone -> Point" on
		(
			for b in bones do
			(
				local ptName = prefix + b.name
				local existing = getNodeByName ptName exact:true
				if existing != undefined then
				(
					reusedCount += 1
					append pairs #(b, existing)
				)
				else
				(
					local pt
					if isFacial b.name then
					(
						pt = point cross:on box:off centermarker:off axistripod:off size:2 wirecolor:(color 255 128 0)
					)
					else if (findItem skinBones b) != 0 or (isAlwaysClassified b.name) then
					(
						local style = classifyBone b.name
						pt = point cross:off box:on centermarker:off axistripod:style[3] size:style[2] wirecolor:style[1]
					)
					else
					(
						pt = point cross:on box:off centermarker:off axistripod:off size:4 wirecolor:(color 135 206 235)
					)
					pt.name = ptName
					if copyRotation then
						pt.transform = b.transform
					else
						pt.pos = b.transform.position
					createdCount += 1
					append pairs #(b, pt)
				)
			)

			for p in pairs do
			(
				local bone = p[1]
				local pt = p[2]
				if bone.parent != undefined do
				(
					local parentPt = getNodeByName (prefix + bone.parent.name) exact:true
					if parentPt != undefined do pt.parent = parentPt
				)
			)
		)
		#(createdCount, reusedCount, bones.count, bones, pairs)
	)
)

struct SkinSaveTool
(
	prefix = "skin_",
	folder = undefined,

	-- Returns #(savedCount, renamedCount, errors_array).
	fn run =
	(
		local savedCount = 0
		local renamedCount = 0
		local errors = #()

		local outFolder = folder
		if outFolder == undefined do
			outFolder = if maxFilePath != "" then maxFilePath else sysInfo.tempdir

		undo "Save Skin Data" on
		(
			for n in objects do
			(
				local skinMod = undefined
				try
				(
					for m in n.modifiers do
						if skinMod == undefined and (classOf m) == Skin do skinMod = m
				)
				catch ()

				if skinMod != undefined do
				(
					if not (matchPattern n.name pattern:(prefix + "*")) do
					(
						n.name = prefix + n.name
						renamedCount += 1
					)

					local envPath = outFolder + n.name + ".env"
					try
					(
						skinOps.saveEnvelope skinMod envPath
						savedCount += 1
					)
					catch
					(
						append errors (n.name + ": " + ((getCurrentException()) as string))
					)
				)
			)
		)
		#(savedCount, renamedCount, errors)
	)
)

try ( destroyDialog YG_skinToPoint ) catch()

rollout YG_skinToPoint "Skin Tools" width:160 height:92
(
	button btn_skinSave    "Save Skin Data"     pos:[8,8]  width:144 height:32 align:#left
	button btn_skinToPoint "Skin Bone -> Point" pos:[8,48] width:144 height:32 align:#left

	on btn_skinSave pressed do
	(
		local t = SkinSaveTool prefix:"skin_"
		local result = t.run()
		local msg = "Saved envelopes: " + (result[1] as string) + \
			"\nRenamed meshes: " + (result[2] as string)
		if result[3].count > 0 do
		(
			msg += "\n\nErrors:\n"
			for e in result[3] do msg += "  " + e + "\n"
		)
		messageBox msg title:"Save Skin Data"
	)

	on btn_skinToPoint pressed do
	(
		-- Full bones->points swap workflow with progress bar:
		--   1) Save Skin envelopes (rename meshes to skin_*)
		--   2) Snapshot each Skin's bone-name list
		--   3) Create pt_* points mirroring the rig hierarchy
		--   4) Delete the original bones (root + descendants)
		--   5) Rename ALL pt_* points to drop the prefix
		--   6) Re-register the (renamed) points as Skin bones and reload envelopes

		local prefix = "pt_"
		local prefixLen = prefix.count
		local reloadedCount = 0
		local reAddedCount = 0
		local skinSnapshots = #()

		progressStart "Skin -> Point"

		progressUpdate 0
		local saveT = SkinSaveTool prefix:"skin_"
		local saveResult = saveT.run()
		progressUpdate 15

		for n in objects do
		(
			for m in n.modifiers where (classOf m) == Skin do
			(
				local names = #()
				local cnt = 0
				try ( cnt = skinOps.GetNumberBones m ) catch ()
				for i = 1 to cnt do
				(
					local bn = ""
					try ( bn = skinOps.GetBoneName m i 0 ) catch ()
					if bn != "" do append names bn
				)
				append skinSnapshots #(n, m, names)
			)
		)
		progressUpdate 25

		local toPointT = SkinToPointTool prefix:prefix copyRotation:true
		local pointResult = toPointT.run()
		local bones = pointResult[4]
		progressUpdate 50

		undo "Bones -> Points swap" on
		(
			if bones.count > 0 do try ( delete bones ) catch ()
			progressUpdate 65

			for n in objects where (classOf n) == Point and (matchPattern n.name pattern:(prefix + "*")) do
			(
				try ( n.name = substring n.name (prefixLen + 1) (n.name.count - prefixLen) ) catch ()
			)
			progressUpdate 80

			local envFolder = if maxFilePath != "" then maxFilePath else sysInfo.tempdir
			local snapTotal = skinSnapshots.count
			for si = 1 to snapTotal do
			(
				local entry = skinSnapshots[si]
				local mesh = entry[1]
				local skinMod = entry[2]
				local boneNames = entry[3]

				for bn in boneNames do
				(
					local pt = getNodeByName bn exact:true
					if pt != undefined do
					(
						try ( skinOps.AddBone skinMod pt 0; reAddedCount += 1 ) catch ()
					)
				)

				local envPath = envFolder + mesh.name + ".env"
				if doesFileExist envPath do
				(
					try ( skinOps.loadEnvelope skinMod envPath; reloadedCount += 1 ) catch ()
				)

				progressUpdate (80 + (20 * si / (amax #(snapTotal, 1))))
			)
		)

		progressUpdate 100
		progressEnd()

		local msg = "[Save] saved:" + (saveResult[1] as string) + \
			" renamed:" + (saveResult[2] as string) + "\n" + \
			"[Points] created:" + (pointResult[1] as string) + \
			" reused:" + (pointResult[2] as string) + \
			" total:" + (pointResult[3] as string) + "\n" + \
			"[Swap] bones deleted:" + (bones.count as string) + \
			"  bones re-added:" + (reAddedCount as string) + \
			"  envelopes reloaded:" + (reloadedCount as string)
		if saveResult[3].count > 0 do
		(
			msg += "\n\nSkin save errors:\n"
			for e in saveResult[3] do msg += "  " + e + "\n"
		)
		messageBox msg title:"Skin -> Point"
	)
)
createDialog YG_skinToPoint
