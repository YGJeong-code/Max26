-- bipToPoint.ms — entry point
-- Loads lib/* tool structs and opens the rollout. Each button wraps its work in
-- undo and validates required scene nodes before running.

-- `local` is illegal at file top level in MaxScript, so resolve the folder inline.
fileIn ((getFilenamePath (getSourceFileName())) + "lib/structs.ms")
fileIn ((getFilenamePath (getSourceFileName())) + "lib/makeBiped.ms")
fileIn ((getFilenamePath (getSourceFileName())) + "lib/makePoint.ms")
fileIn ((getFilenamePath (getSourceFileName())) + "lib/bipAlign.ms")
fileIn ((getFilenamePath (getSourceFileName())) + "lib/fbxToBip.ms")
fileIn ((getFilenamePath (getSourceFileName())) + "lib/layer.ms")
fileIn ((getFilenamePath (getSourceFileName())) + "lib/ikBone.ms")
fileIn ((getFilenamePath (getSourceFileName())) + "lib/rootMotion.ms")

try ( destroyDialog YG_bipToPoint ) catch()

rollout YG_bipToPoint "Biped To Point" width:152 height:288
(
	-- Struct instances are local to the rollout to avoid polluting global scope.
	local myBipStruct, myPointStruct, myFbxStruct

	groupBox grp_build  "Build"  pos:[4,4]   width:144 height:178
	button btn_makeBip          "1. Make Biped"           pos:[8,20]  width:136 height:32 align:#left
	button btn_makePoint        "2. Make Point"           pos:[8,60]  width:136 height:32 align:#left
	button btn_bipToPoint       "3. Biped To Point"       pos:[8,100] width:136 height:32 align:#left
	button btn_fbxConnectToBip  "4. FBX connect To Biped" pos:[8,140] width:136 height:32 align:#left

	groupBox grp_extras "Extras" pos:[4,188] width:144 height:96
	button btn_IKBone           "IK Bone"                 pos:[8,204] width:136 height:32 align:#left
	button btn_rootMotion       "Root Motion"             pos:[8,244] width:136 height:32 align:#left

	fn refreshStructs =
	(
		myBipStruct = bipStruct()
		myPointStruct = pointStruct()
		myFbxStruct = fbxStruct()
	)

	fn showError msg = ( messageBox msg title:"bipToPoint" )

	on btn_makeBip pressed do
	(
		undo "Make Biped" on
		(
			(MakeBipedTool()).run()
		)
		refreshStructs()
		clearSelection()
	)

	on btn_makePoint pressed do
	(
		refreshStructs()
		if myBipStruct.myPelvis == undefined then
			showError "Biped not found in scene. Run step 1 first."
		else if myFbxStruct.myPelvis == undefined then
			showError "FBX skeleton (pelvis) not found in scene."
		else
		(
			undo "Make Point" on
			(
				local t = MakePointTool bipS:myBipStruct pointS:myPointStruct fbxS:myFbxStruct
				t.run()
			)
			refreshStructs()
		)
	)

	on btn_bipToPoint pressed do
	(
		refreshStructs()
		if myBipStruct.myPelvis == undefined then
			showError "Biped not found in scene."
		else if myPointStruct.myPelvisPT == undefined then
			showError "Point helpers (pt_*) not found. Run step 2 first."
		else if myFbxStruct.myPelvis == undefined then
			showError "FBX skeleton not found in scene."
		else
		(
			undo "Biped To Point" on
			(
				local t = BipAlignTool bipS:myBipStruct pointS:myPointStruct fbxS:myFbxStruct
				t.run()
			)
		)
	)

	on btn_fbxConnectToBip pressed do
	(
		refreshStructs()
		if myBipStruct.myPelvis == undefined then
			showError "Biped not found in scene."
		else if myFbxStruct.myPelvis == undefined then
			showError "FBX skeleton not found in scene."
		else
		(
			undo "FBX Connect To Biped" on
			(
				local t = FbxToBipTool bipS:myBipStruct fbxS:myFbxStruct
				t.run()

				local lTool = LayerTool bipS:myBipStruct fbxS:myFbxStruct
				lTool.arrange()
			)
		)
	)

	on btn_IKBone pressed do
	(
		if (isValidNode (execute "$root")) == false then
			showError "Root bone ($root) not found. IK Bones need the FBX hierarchy."
		else if (isValidNode (execute "$foot_l")) == false or (isValidNode (execute "$hand_l")) == false then
			showError "Required FBX bones (foot_l/hand_l) not found."
		else
		(
			undo "IK Bone" on
			(
				(IKBoneTool()).run()
			)
		)
	)

	on btn_rootMotion pressed do
	(
		refreshStructs()
		if myBipStruct.myBip == undefined or myBipStruct.myPelvis == undefined then
			showError "Biped not found in scene. Run step 1 first."
		else
		(
			undo "Root Motion" on
			(
				local t = RootMotionTool bipS:myBipStruct
				t.run()
			)
		)
	)

)
createDialog YG_bipToPoint
