-- Compatible: 3ds Max 2024+
-- bipToPoint/lib/layer.ms
-- Organize scene nodes into named export/control layers (UE-style export pipeline).
-- Missing nodes are silently skipped so layerArrange is safe on partial scenes.

struct LayerTool
(
	bipS,
	fbxS,

	-- Resolve a node by exact name; returns undefined if absent.
	fn _byName nm = getNodeByName nm exact:true,

	-- Add a node to a layer only if the node exists.
	fn _addByName layer nm =
	(
		local n = _byName nm
		if n != undefined do layer.addnode n
	),

	-- Add several nodes by name list.
	fn _addManyByName layer names =
	(
		for nm in names do _addByName layer nm
	),

	-- Append every descendant of `node` into `arr`.
	fn getAllChildren node arr =
	(
		for c in node.children do
		(
			append arr c
			getAllChildren c arr
		)
		arr
	),

	fn arrange =
	(
		local myLayerList = #("99_CurrectiveBone","01_ExportMesh_F","01_ExportMesh_M","02_ExportBone","03_ExportSubBone","10_ControllerBiped",
			"11_Weapon","99_Nub","99_XtrasBone")

		for i in myLayerList do
		(
			local myLayer = LayerManager.getLayerFromName i
			if myLayer == undefined then
			(
				myLayer = LayerManager.newLayer()
				myLayer.setName i
			)

			if i == "99_CurrectiveBone" then
			(
				myLayer.on = false

				local rootObj = _byName "root"
				if rootObj != undefined do
				(
					local myList = #(rootObj)
					getAllChildren rootObj myList
					for j in myList do myLayer.addnode j
				)
			)
			if i == "02_ExportBone" then
			(
				-- Twist bones (upperarm_twist_*, lowerarm_twist_*, thigh_twist_*,
				-- calf_twist_*) stay in 99_CurrectiveBone where the root-walk put them.
				for j in fbxS.myAllList where j != undefined and \
					(findString j.name "_twist_" == undefined) do myLayer.addnode j

				_addManyByName myLayer #(
					"root", "neck_02", "spine_01", "spine_05",
					"index_metacarpal_l", "index_metacarpal_r",
					"middle_metacarpal_l", "middle_metacarpal_r",
					"pinky_metacarpal_l", "pinky_metacarpal_r",
					"ring_metacarpal_l", "ring_metacarpal_r",
					"weapon_l", "weapon_r"
				)

				myLayer.on = false
			)
			if i == "10_ControllerBiped" then
			(
				for j in bipS.myAllList where j != undefined do myLayer.addnode j

				-- Biped root + props use space-containing names — use execute "$..."
				-- to leverage $ fuzzy matching.
				local myName = "Bip001"
				local myBip   = execute ("$" + myName)
				local myPropL = execute ("$" + myName + "Prop2")
				local myPropR = execute ("$" + myName + "Prop1")

				if myBip   != undefined do myLayer.addnode myBip
				if myPropL != undefined do myLayer.addnode myPropL
				if myPropR != undefined do myLayer.addnode myPropR

				-- No-idx twist links (LUpArmTwist / L ForeTwist / LThighTwist / LCalfTwist
				-- + R mirrors) — created by Biped but unmapped in b2p_BoneMap, so they're
				-- not in myAllList. Add them here so they live in the Biped controller layer.
				-- Suffix written without spaces — $ fuzzy match resolves "Bip001LForeTwist"
				-- to the real "Bip001 L ForeTwist". A literal space in the executed string
				-- breaks the parser (interpreted as call syntax).
				local twistRoots = #(
					"LUpArmTwist",  "RUpArmTwist",
					"LForeTwist",   "RForeTwist",
					"LThighTwist",  "RThighTwist",
					"LCalfTwist",   "RCalfTwist"
				)
				for suf in twistRoots do
				(
					local n = execute ("$" + myName + suf)
					if n != undefined do myLayer.addnode n
				)
			)
			if i == "99_Nub" then
			(
				-- Biped Nubs have spaces in their names — execute "$..." fuzzy match.
				local myName = "Bip001"
				local nubSuffixes = #("Footsteps", "HeadNub",
					"LFinger0Nub", "LFinger1Nub", "LFinger2Nub", "LFinger3Nub", "LFinger4Nub",
					"LToe0Nub",
					"RFinger0Nub", "RFinger1Nub", "RFinger2Nub", "RFinger3Nub", "RFinger4Nub",
					"RToe0Nub")
				for suf in nubSuffixes do
				(
					local n = execute ("$" + myName + suf)
					if n != undefined do myLayer.addnode n
				)

				myLayer.on = false
			)
			if i == "01_ExportMesh_M" then
			(
				for obj in objects where (classOf obj) == PolyMeshObject do myLayer.addnode obj

				myLayer.isfrozen = True
			)
		)
	)
)
