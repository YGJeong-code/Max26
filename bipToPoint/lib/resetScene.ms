-- Compatible: 3ds Max 2024+
-- bipToPoint/lib/resetScene.ms
-- Restore the scene to its pre-rig state: keep only FBX skeleton bones (root
-- and all descendants) and geometry meshes. Strip Position_Constraint /
-- Orientation_Constraint from FBX bones so they revert to plain Bezier / Euler
-- controllers, then delete everything else (Biped, point helpers, IK helpers,
-- root-motion rig, weapons, etc).

struct ResetSceneTool
(
	-- Walk a node and append every descendant into `arr` (depth-first).
	fn _collectDescendants n arr =
	(
		append arr n
		for c in n.children do _collectDescendants c arr
	),

	fn run =
	(
		local rootObj = getNodeByName "root" exact:true
		if rootObj == undefined then
		(
			messageBox "FBX root not found." title:"Reset Scene"
			return false
		)

		-- Collect FBX bones (root + descendants).
		local fbxBones = #()
		_collectDescendants rootObj fbxBones

		-- Snapshot every FBX bone's world transform BEFORE touching controllers.
		-- Replacing position.controller = Position_XYZ() (and rotation similarly)
		-- can reset the bone to identity rather than preserving the current
		-- evaluated value, so we save the transforms and restore them after.
		-- fbxBones is in depth-first (parent-before-child) order from
		-- _collectDescendants, so restoring in the same order preserves the
		-- hierarchy correctly.
		local savedXforms = for b in fbxBones collect b.transform

		-- Replace controllers to clean defaults (drops any Position_Constraint /
		-- Orientation_Constraint, list-wrapped or not).
		local strippedPos = 0
		local strippedRot = 0
		for b in fbxBones do
		(
			try ( b.position.controller = Position_XYZ(); strippedPos += 1 ) catch ()
			try ( b.rotation.controller = Euler_XYZ();    strippedRot += 1 ) catch ()
		)

		-- Restore world transforms. Parent-first iteration means each child's
		-- local transform is computed against the already-restored parent.
		for i in 1 to fbxBones.count do
		(
			try ( fbxBones[i].transform = savedXforms[i] ) catch ()
		)

		-- Identify meshes: GeometryClass nodes that are NOT biped bones.
		-- (Biped_Object falls under GeometryClass via isKindOf, so without an
		-- explicit exclusion the biped would be classified as mesh and kept.)
		local meshes = for o in objects where \
			((superClassOf o) == GeometryClass) and \
			((classOf o) != Biped_Object) \
			collect o

		-- Build keep set and snapshot counts BEFORE deletion so we don't
		-- iterate `keep` afterwards (some refs may go invalid mid-delete).
		local keep = #()
		for n in fbxBones do append keep n
		for n in meshes   do appendIfUnique keep n
		local bonesCount = fbxBones.count
		local meshCount  = meshes.count

		-- Delete everything not in keep in one batch (single undo step).
		local toDelete = for o in objects where (findItem keep o) == 0 collect o
		local removed = toDelete.count
		if removed > 0 do delete toDelete

		format "Reset Scene: kept % FBX bones + % meshes, deleted % nodes (pos constraints stripped: %, rot: %)\n" \
			bonesCount meshCount removed strippedPos strippedRot
		true
	)
)
