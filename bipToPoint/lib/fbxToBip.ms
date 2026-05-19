-- bipToPoint/lib/fbxToBip.ms
-- Step 4: Constrain FBX bones to follow Biped bones (position + orientation),
-- then drop figure mode so animation can drive the rig.

struct FbxToBipTool
(
	bipS,
	fbxS,

	fn run =
	(
		for i in 1 to fbxS.myAllList.count do
		(
			local fbxNode = fbxS.myAllList[i]
			local bipNode = bipS.myAllList[i]
			if fbxNode == undefined or bipNode == undefined do continue

			-- Rotation constraint for every mapped bone.
			fbxNode.rotation.controller = Orientation_Constraint ()
			fbxNode.rotation.controller.relative = on
			fbxNode[3][2].constraints.appendTarget bipNode 50

			-- Position constraint is skipped for twist bones — twists inherit
			-- position from their parent limb bone, only their rotation is
			-- driven by the biped twist.
			local isTwist = (findString fbxNode.name "_twist_" != undefined)
			if not isTwist do
			(
				fbxNode.position.controller = Position_Constraint ()
				fbxNode.position.controller.relative = on
				fbxNode[3][1].constraints.appendTarget bipNode 50
			)
		)

		local biped_ctrl = bipS.myBip.controller
		biped_ctrl.figureMode = false
	)
)
