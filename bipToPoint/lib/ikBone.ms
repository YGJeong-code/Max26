-- Compatible: 3ds Max 2024+
-- bipToPoint/lib/ikBone.ms
-- Create UE-style IK driver points (ik_foot_*, ik_hand_*) constrained to FBX hand/foot.
-- Re-running deletes any existing nodes with these names first to avoid duplicates
-- like "ik_foot_l001".

struct IKBoneTool
(
	-- Resolve a node by name, returning undefined if not present.
	fn _byName nm = getNodeByName nm exact:true,

	-- Constrain pt's rotation+position to target with weight 50.
	fn _constrainTo pt target =
	(
		if pt == undefined or target == undefined do return false
		pt.rotation.controller = Orientation_Constraint ()
		pt.rotation.controller.relative = off
		pt[3][2].constraints.appendTarget target 50

		pt.position.controller = Position_Constraint ()
		pt.position.controller.relative = off
		pt[3][1].constraints.appendTarget target 50
	),

	fn run =
	(
		local nameList = #("ik_foot_root", "ik_foot_l", "ik_foot_r", "ik_hand_root", "ik_hand_l", "ik_hand_r")

		-- Clean up any prior IK helpers so re-running is idempotent.
		for n in nameList do
		(
			local existing = _byName n
			if existing != undefined do delete existing
		)

		-- Create fresh helpers.
		for i in nameList do
		(
			local pt = point transform:(matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]) \
				size:5 Box:off axistripod:on cross:off centermarker:off
			pt.name = i
		)

		-- Parent chain (skip silently if the FBX root is missing).
		local rootNode = _byName "root"
		local ikFootRoot = _byName "ik_foot_root"
		local ikFootL    = _byName "ik_foot_l"
		local ikFootR    = _byName "ik_foot_r"
		local ikHandRoot = _byName "ik_hand_root"
		local ikHandL    = _byName "ik_hand_l"
		local ikHandR    = _byName "ik_hand_r"

		if rootNode != undefined do
		(
			ikFootRoot.parent = rootNode
			ikHandRoot.parent = rootNode
		)
		ikFootL.parent = ikFootRoot
		ikFootR.parent = ikFootRoot
		ikHandL.parent = ikHandRoot
		ikHandR.parent = ikHandRoot

		-- Constraints (silently skip if target FBX bone is missing).
		_constrainTo ikFootL (_byName "foot_l")
		_constrainTo ikFootR (_byName "foot_r")
		_constrainTo ikHandL (_byName "hand_l")
		_constrainTo ikHandR (_byName "hand_r")

		-- Layer (only if the layer already exists from layerArrange).
		local myLayer = LayerManager.getLayerFromName "02_ExportBone"
		if myLayer != undefined do
		(
			for nm in nameList do
			(
				local n = _byName nm
				if n != undefined do myLayer.addnode n
			)
		)
	)
)
