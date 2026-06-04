-- Compatible: 3ds Max 2024+
-- bipToPoint/lib/rootMotion.ms
-- Root-motion helper rig:
--   99_XtrasBone layer:
--     RootIKPoint1_Xtras (Point, child of Bip001) — anchor at pelvis (red box, size 30)
--     RootIKEx1/2_Xtras  (ExposeTm, children of Point1) — transform sampling (yellow cross, size 30)
--     RootIKPoint2_Xtras (Point) — forward anchor (red box, size 30)
--     RootIK01/02/03_Xtras (Points, bent 3-joint chain) — pelvis to floor (yellow cross, size 30)
--     IK_Chain_Object on RootIK01 -> RootIK03
--   10_ControllerBiped layer:
--     RootController_Xtras (Point + Attribute Holder with root-motion flags, red box, size 25)
-- Offsets are derived as ratios of pelvis Z so the rig scales with character height.

-- CA definition for the RootController Attribute Holder. Re-running this file
-- updates the existing def (MaxScript semantics) so multiple loads are safe.
-- Capture the CA def directly via `attributes` as an expression. In this Max
-- environment the bare name (Custom_Attributes) does NOT bind globally, but the
-- block's return value does — so we assign it into a global we control.
global gRootMotionCA

gRootMotionCA = attributes Custom_Attributes version:3
(
	-- Params are #float (Bezier_Float subAnims, wire-able). Checkboxes ↔ float
	-- sync is done manually since MaxScript doesn't auto-bind checkbox to #float.
	parameters main rollout:rollMain
	(
		AllowRootRotation type:#float default:0.0
		AllowRootMovement type:#float default:1.0
		XAxis             type:#float default:0.0
		YAxis             type:#float default:1.0
	)
	rollout rollMain "Root Controller"
	(
		checkbox cb_rot "Allow Root Rotation"
		checkbox cb_mov "Allow Root Movement"
		checkbox cb_x   "X Axis" align:#center
		checkbox cb_y   "Y Axis" align:#center

		on rollMain open do
		(
			cb_rot.checked = (AllowRootRotation > 0.5)
			cb_mov.checked = (AllowRootMovement > 0.5)
			cb_x.checked   = (XAxis > 0.5)
			cb_y.checked   = (YAxis > 0.5)
		)
		on cb_rot changed state do AllowRootRotation = (if state then 1.0 else 0.0)
		on cb_mov changed state do AllowRootMovement = (if state then 1.0 else 0.0)
		on cb_x   changed state do XAxis             = (if state then 1.0 else 0.0)
		on cb_y   changed state do YAxis             = (if state then 1.0 else 0.0)
	)
)

fn _attachRootMotionCA mod =
(
	if gRootMotionCA == undefined then
		format "RootMotion CA: gRootMotionCA undefined at attach time.\n"
	else
	(
		try ( custAttributes.add mod gRootMotionCA )
		catch ( format "RootMotion CA attach failed: %\n" (getCurrentException()) )
	)
)

-- Walk subAnims of `parent` and find one whose name matches any target (case-insensitive).
fn _findSubByAny parent targets =
(
	if parent == undefined then undefined
	else
	(
		local result = undefined
		local n = 0
		try ( n = parent.numSubs ) catch ()
		local lcTargets = for t in targets collect (toLower t)
		for i = 1 to n while result == undefined do
		(
			local s = undefined
			try ( s = getSubAnim parent i ) catch ()
			if s != undefined do
			(
				local nm = ""
				try ( nm = toLower ((getSubAnimName parent i) as string) ) catch ()
				for t in lcTargets while result == undefined do
					if nm == t do result = s
			)
		)
		result
	)
)

-- Dump all subAnims of an animatable for debugging (name + class).
fn _dumpSubs label obj =
(
	if obj == undefined then format "  [%] undefined\n" label
	else
	(
		local n = 0
		try ( n = obj.numSubs ) catch ()
		format "  [%] numSubs:%  obj:%\n" label n obj
		for i = 1 to n do
		(
			local sub = undefined
			try ( sub = getSubAnim obj i ) catch ()
			local nm = ""
			try ( nm = (getSubAnimName obj i) as string ) catch ()
			format "    [% %] '%' -> %\n" label i nm sub
		)
	)
)

-- Connect one parameter wire. Silent on success; logs only failures.
fn _doWire fromSub toSub expr label =
(
	if fromSub == undefined or toSub == undefined then
	(
		format "  wire %: SKIP (undefined sub — from:% to:%)\n" label fromSub toSub
		false
	)
	else
	(
		local ok = false
		try ( ok = paramWire.connect fromSub toSub expr )
		catch ( format "  wire %: EXCEPTION %\n" label (getCurrentException()) )
		if not ok do format "  wire %: FAIL\n" label
		ok
	)
)

-- Set up RootController_Xtras's controller tree (Position_List + Float_Limits + Rotation_List)
-- and create the 11 parameter wires connecting CA flags / ExposeTm outputs / IK goal.
-- ex1 = RootIKEx1_Xtras (exposes RootIK03 — foot position, for X/Y root motion)
-- ex2 = RootIKEx2_Xtras (exposes Bip001 — body rotation, for Z heading)
fn _setupRootMotionWires rc ex1 ex2 ikChain bipRoot =
(
	-- Reset rc's transform sub-controllers. On a re-run rc carries wires to
	-- nodes we just deleted, so we need a clean teardown. The reset type
	-- matters: Position_List() *inherits* the prior controller as its sub 1,
	-- so we set Position_XYZ first to make sub 1 the correct type. Same for
	-- Rotation_List inheriting Euler_XYZ.
	try ( rc.position.controller = Position_XYZ() ) catch ()
	try ( rc.rotation.controller = Euler_XYZ() ) catch ()

	-- 1. Position controller tree.
	-- Reference: 2 Position_XYZ subs with active=2; wires + Float_Limits on sub 1
	-- (root-motion sub), sub 2 is the rest/edit sub.
	rc.position.controller = Position_List()
	rc.position.controller.Available.controller = Position_XYZ()  -- sub 1
	local pxyz = rc.position.controller[1].controller  -- sub 1: where wires connect

	pxyz.x_position.controller = Float_Limit()
	local xLim = pxyz.x_position.controller
	xLim.upper_limit_enabled = true
	xLim.lower_limit_enabled = true

	pxyz.y_position.controller = Float_Limit()
	local yLim = pxyz.y_position.controller
	yLim.upper_limit_enabled = true
	yLim.lower_limit_enabled = true

	-- Add the rest sub AFTER Float_Limits, so the index-based access above stays valid.
	rc.position.controller.Available.controller = Position_XYZ()  -- sub 2

	-- 2. Rotation controller tree.
	-- Reference: 2 Euler_XYZ subs with active=1; z_rotation wire on sub 2.
	rc.rotation.controller = Rotation_List()
	rc.rotation.controller.Available.controller = Euler_XYZ()  -- sub 1
	rc.rotation.controller.Available.controller = Euler_XYZ()  -- sub 2
	local exyz = rc.rotation.controller[2].controller  -- sub 2: where z_rotation wire connects

	-- Remove the trailing Available slot to match reference (count: 2, no Available).
	local posListPre = rc.position.controller.count
	local rotListPre = rc.rotation.controller.count
	try ( rc.position.controller.delete rc.position.controller.count ) catch ()
	try ( rc.rotation.controller.delete rc.rotation.controller.count ) catch ()
	if rc.position.controller.count == posListPre do
		try ( (getInterface rc.position.controller #IListControl).delete posListPre ) catch ()
	if rc.rotation.controller.count == rotListPre do
		try ( (getInterface rc.rotation.controller #IListControl).delete rotListPre ) catch ()

	-- 3. Master subAnims — try multiple access paths since name binding inside fn
	-- scope is unreliable in this Max environment.
	-- ex1 (RootIKEx1, exposes RootIK03 = foot) — drives RC position (root motion)
	-- ex2 (RootIKEx2, exposes Bip001 = body) — drives RC rotation AND IK goal
	--    (using ex2 for IK goal avoids cycle: RootIKEx1 -> IK -> RootIK03 -> RootIKEx1)
	local ex1WorldX = undefined
	local ex1WorldY = undefined
	local ex2WorldX = undefined
	local ex2WorldY = undefined
	local ex2EulerZ = undefined
	try ( ex1WorldX = ex1.baseObject[#Expose][#World_Position_X] ) catch ()
	try ( ex1WorldY = ex1.baseObject[#Expose][#World_Position_Y] ) catch ()
	try ( ex2WorldX = ex2.baseObject[#Expose][#World_Position_X] ) catch ()
	try ( ex2WorldY = ex2.baseObject[#Expose][#World_Position_Y] ) catch ()
	try ( ex2EulerZ = ex2.baseObject[#Expose][#World_Euler_Z] ) catch ()
	if ex1WorldX == undefined do try ( ex1WorldX = ex1.baseObject[#World_Position_X] ) catch ()
	if ex1WorldY == undefined do try ( ex1WorldY = ex1.baseObject[#World_Position_Y] ) catch ()
	if ex2WorldX == undefined do try ( ex2WorldX = ex2.baseObject[#World_Position_X] ) catch ()
	if ex2WorldY == undefined do try ( ex2WorldY = ex2.baseObject[#World_Position_Y] ) catch ()
	if ex2EulerZ == undefined do try ( ex2EulerZ = ex2.baseObject[#World_Euler_Z] ) catch ()
	if ex1WorldX == undefined do try ( ex1WorldX = getSubAnim ex1.baseObject 14 ) catch ()
	if ex1WorldY == undefined do try ( ex1WorldY = getSubAnim ex1.baseObject 15 ) catch ()
	if ex2WorldX == undefined do try ( ex2WorldX = getSubAnim ex2.baseObject 14 ) catch ()
	if ex2WorldY == undefined do try ( ex2WorldY = getSubAnim ex2.baseObject 15 ) catch ()
	if ex2EulerZ == undefined do try ( ex2EulerZ = getSubAnim ex2.baseObject 8 ) catch ()

	-- CA — try path syntax, then bracket, then custAttributes.get fallback.
	local mod = undefined
	try ( mod = rc.modifiers[#Attribute_Holder] ) catch ()
	if mod == undefined do try ( mod = rc.modifiers[1] ) catch ()

	local caInst = undefined
	if mod != undefined do
	(
		try ( caInst = mod.Custom_Attributes ) catch ()
		if caInst == undefined do try ( caInst = mod[#Custom_Attributes] ) catch ()
		if caInst == undefined do try ( caInst = custAttributes.get mod 1 ) catch ()
	)

	local caRot = undefined
	local caMov = undefined
	local caX   = undefined
	local caY   = undefined
	-- Path A: inline chain from node
	try ( caRot = rc.modifiers[#Attribute_Holder].Custom_Attributes[#AllowRootRotation] ) catch ()
	try ( caMov = rc.modifiers[#Attribute_Holder].Custom_Attributes[#AllowRootMovement] ) catch ()
	try ( caX   = rc.modifiers[#Attribute_Holder].Custom_Attributes[#XAxis] ) catch ()
	try ( caY   = rc.modifiers[#Attribute_Holder].Custom_Attributes[#YAxis] ) catch ()
	-- Path B: bracket access directly on the modifier (CA params often surface
	-- as modifier sub-properties without the CA layer)
	if caRot == undefined do try ( caRot = mod[#AllowRootRotation] ) catch ()
	if caMov == undefined do try ( caMov = mod[#AllowRootMovement] ) catch ()
	if caX == undefined do try ( caX = mod[#XAxis] ) catch ()
	if caY == undefined do try ( caY = mod[#YAxis] ) catch ()
	-- Path C: indexed getSubAnim on modifier
	if caRot == undefined do try ( caRot = getSubAnim mod 1 ) catch ()
	if caMov == undefined do try ( caMov = getSubAnim mod 2 ) catch ()
	if caX == undefined do try ( caX = getSubAnim mod 3 ) catch ()
	if caY == undefined do try ( caY = getSubAnim mod 4 ) catch ()
	if caRot == undefined or caX == undefined do
	(
		format "Warning: CA params undefined. Probe:\n"
		_dumpSubs "mod" mod
	)

	-- 4. Slave subAnims via user's known-working syntax:
	--   xLim[#Limited_Controller__Bezier_Float]   (fresh Float_Limit wraps Bezier_Float)
	--   xLim[#Limits][#Upper_Limit]               (capital L Limits)
	local xLimitedCtl = undefined
	try ( xLimitedCtl = xLim[#Limited_Controller__Bezier_Float] ) catch ()
	local xUpper = undefined
	local xLower = undefined
	try ( xUpper = xLim[#Limits][#Upper_Limit] ) catch ()
	try ( xLower = xLim[#Limits][#Lower_Limit] ) catch ()

	local yLimitedCtl = undefined
	try ( yLimitedCtl = yLim[#Limited_Controller__Bezier_Float] ) catch ()
	local yUpper = undefined
	local yLower = undefined
	try ( yUpper = yLim[#Limits][#Upper_Limit] ) catch ()
	try ( yLower = yLim[#Limits][#Lower_Limit] ) catch ()

	-- Diagnostic: show Float_Limit substructure if any slot is missing
	if xLimitedCtl == undefined or xUpper == undefined or xLower == undefined do
	(
		format "Float_Limit subAnim probe:\n"
		_dumpSubs "xLim" xLim
		try ( _dumpSubs "xLim[#Limits]" xLim[#Limits] ) catch ()
	)

	-- Position_List Weights — wire goes to weight[1] (sub 1 is the wired sub).
	local posWeights = undefined
	try ( posWeights = rc.pos.controller[#Weights] ) catch ()
	if posWeights == undefined do try ( posWeights = _findSubByAny rc.pos.controller #("Weights") ) catch ()
	local posWeightXYZ = undefined
	if posWeights != undefined do try ( posWeightXYZ = getSubAnim posWeights 1 ) catch ()

	-- Rotation_List Weights — wire goes to weight[2] (sub 2 is the wired sub).
	-- weight[2] defaults to 0 (since AllowRootRotation default is false), so root
	-- rotation is OFF unless the user toggles the CA flag.
	local rotWeights = undefined
	try ( rotWeights = rc.rotation.controller[#Weights] ) catch ()
	if rotWeights == undefined do try ( rotWeights = _findSubByAny rc.rotation.controller #("Weights") ) catch ()
	local rotWeightXYZ = undefined
	if rotWeights != undefined do try ( rotWeightXYZ = getSubAnim rotWeights 2 ) catch ()

	-- Euler_XYZ.z_rotation slot (subAnim 3)
	local zRot = undefined
	try ( zRot = exyz[#Z_Rotation] ) catch ()
	if zRot == undefined do try ( zRot = getSubAnim exyz 3 ) catch ()

	-- 5. Compute rotation offset so Bip001's current Z euler becomes "zero" in readout
	local zOffset = 0.0
	try ( zOffset = -((bipRoot.transform.rotation as eulerAngles).z) ) catch ()
	local zExpr = "World_Euler_Z+" + (zOffset as string)

	-- 6. Wires on RootController (9).
	_doWire ex1WorldX xLimitedCtl "World_Position_X" "x.Limited_Controller"
	_doWire caX xUpper "XAxis*100000" "x.Upper_Limit"
	_doWire caX xLower "XAxis*-100000" "x.Lower_Limit"
	_doWire ex1WorldY yLimitedCtl "World_Position_Y" "y.Limited_Controller"
	_doWire caY yUpper "YAxis*100000" "y.Upper_Limit"
	_doWire caY yLower "YAxis*-100000" "y.Lower_Limit"
	_doWire caMov posWeightXYZ "AllowRootMovement" "pos.Weight"
	_doWire ex2EulerZ zRot zExpr "rot.z"
	_doWire caRot rotWeightXYZ "AllowRootRotation" "rot.Weight"

	-- 7. Wires on IK Chain001 IK goal (2)
	if ikChain != undefined do
	(
		local ikGoal = _findSubByAny ikChain.controller #("IK Goal", "IK_goal", "IK_Goal")
		local ikGoalPos = _findSubByAny ikGoal #("Position", "position")
		local ikGoalX = _findSubByAny ikGoalPos #("X Position", "X_Position", "x_position")
		local ikGoalY = _findSubByAny ikGoalPos #("Y Position", "Y_Position", "y_position")
		-- Read IK goal from ex2 (Bip001) to avoid cycle through RootIK03.
		_doWire ex2WorldX ikGoalX "World_Position_X" "ikChain.goal.x"
		_doWire ex2WorldY ikGoalY "World_Position_Y" "ikChain.goal.y"
	)

	-- Force RootController's world rotation to identity (0,0,0):
	-- 1) Zero out sub 1's euler values (rest sub).
	-- 2) Set weight[2] = 0 so the wired sub doesn't contribute initially.
	--    (After the user pastes the CA wires, AllowRootRotation wire takes over,
	--    keeping weight[2] = 0 when the toggle is off, 1 when on.)
	try
	(
		local restEuler = rc.rotation.controller[1].controller
		restEuler.x_rotation = 0
		restEuler.y_rotation = 0
		restEuler.z_rotation = 0
	)
	catch
	(
		format "Warning: could not reset RootController rotation sub 1: %\n" (getCurrentException())
	)
	-- Weight scale is 0-100 in this rig. Non-toggle weights start at 100 (full);
	-- the wired rotation sub weight starts at 0 (driven by AllowRootRotation toggle).
	try ( rc.rotation.controller.weight[1] = 100 ) catch ()
	try ( rc.rotation.controller.weight[2] = 0 ) catch ()
	try ( rc.position.controller.weight[1] = 100 ) catch ()
	try ( rc.position.controller.weight[2] = 100 ) catch ()

	-- Set active subs to match reference: Position->2, Rotation->1.
	try ( rc.position.controller.setActive 2 ) catch ()
	try ( rc.rotation.controller.setActive 1 ) catch ()
)

struct RootMotionTool
(
	bipS,

	-- Visual style constants matched to the reference rig.
	anchorColor = color 255 0 0,
	chainColor  = color 177 148 27,
	defaultSize = 30.0,

	-- Add nodes to a named layer; create the layer if missing. Only set .on
	-- when we created the layer, so an existing user-configured layer is preserved.
	fn addToLayer layerName nodes initialOn:true =
	(
		local layer = LayerManager.getLayerFromName layerName
		local created = false
		if layer == undefined then
		(
			layer = LayerManager.newLayer()
			layer.setName layerName
			created = true
		)
		for n in nodes where n != undefined do layer.addnode n
		if created then layer.on = initialOn
	),

	-- Red box anchor point (Point1, Point2, RootController).
	fn anchorPoint ptPos sizeVal =
	(
		local p = point pos:ptPos cross:off box:on centermarker:off axistripod:off size:sizeVal
		p.wirecolor = anchorColor
		p
	),

	-- Yellow cross helper point (IK chain joints).
	fn chainPoint ptPos sizeVal =
	(
		local p = point pos:ptPos cross:on box:off centermarker:off axistripod:off size:sizeVal
		p.wirecolor = chainColor
		p
	),

	-- Yellow cross ExposeTm helper.
	fn chainExpose tm sizeVal =
	(
		local e = ExposeTm()
		e.transform = tm
		e.size = sizeVal
		e.cross = on
		e.box = off
		e.centermarker = off
		e.axistripod = off
		e.wirecolor = chainColor
		e
	),

	fn makeRootController =
	(
		local rc = getNodeByName "RootController_Xtras"
		if rc != undefined then rc
		else
		(
			rc = anchorPoint [0,0,0] 25.0
			rc.name = "RootController_Xtras"

			-- Attribute Holder modifier (class name is EmptyModifier in MaxScript).
			local m = EmptyModifier()
			m.name = "Attribute_Holder"
			addModifier rc m

			-- CA defs aren't visible from struct method scope, so call the file-top
			-- helper which can resolve Custom_Attributes from its own scope.
			_attachRootMotionCA m

			rc
		)
	),

	fn run =
	(
		local pelvis = bipS.myPelvis
		if pelvis == undefined then throw "Bip001 Pelvis not found in scene."

		local pelvisPos = pelvis.transform.position
		local bipRoot = bipS.myBip
		local H = pelvisPos.z
		if H <= 0 then throw "Bip001 Pelvis must be above world origin (pelvis Z > 0)."

		-- Clean up any prior Xtras nodes so re-running is idempotent. RootController_Xtras
		-- (with its CA) is intentionally preserved by makeRootController via getNodeByName.
		local xtraNames = #("RootIKPoint1_Xtras", "RootIKEx1_Xtras", "RootIKEx2_Xtras", \
			"RootIKPoint2_Xtras", "RootIK01_Xtras", "RootIK02_Xtras", "RootIK03_Xtras", \
			"IK Chain001")
		for nm in xtraNames do
		(
			local existing = getNodeByName nm exact:true
			if existing != undefined do try ( delete existing ) catch ()
		)

		-- Anchor at pelvis, parented to Bip001 so it follows the character.
		local p1 = anchorPoint pelvisPos defaultSize
		p1.name = "RootIKPoint1_Xtras"
		p1.parent = bipRoot

		-- ExposeTm helpers under p1. Refs wired later once IK nodes exist.
		local ex1 = chainExpose (transMatrix (pelvisPos + [0, -3.225, -1.455 * H])) defaultSize
		ex1.name = "RootIKEx1_Xtras"
		ex1.parent = p1

		local ex2 = chainExpose (transMatrix (pelvisPos + [0, -3.225, -0.735 * H])) defaultSize
		ex2.name = "RootIKEx2_Xtras"
		ex2.parent = p1

		-- Forward anchor at pelvis height (50 units in front).
		-- Linked to p1 via Link_Constraint (not scene parent) so it follows the
		-- character anchor without inheriting world rotation.
		local p2 = anchorPoint (pelvisPos + [0, -50, 0]) defaultSize
		p2.name = "RootIKPoint2_Xtras"
		p2.controller = Link_Constraint()
		p2.controller.addTarget p1 0

		-- 3-joint IK chain: pelvis -> bent forward -> floor.
		local ik1 = chainPoint pelvisPos defaultSize
		ik1.name = "RootIK01_Xtras"

		local ik2 = chainPoint (pelvisPos + [0, -H, -0.285 * H]) defaultSize
		ik2.name = "RootIK02_Xtras"
		ik2.parent = ik1

		local ik3 = chainPoint [0, 0, 0] defaultSize
		ik3.name = "RootIK03_Xtras"
		ik3.parent = ik2

		-- IK chain on RootIK01 -> RootIK03.
		local ikChain
		try
		(
			ikChain = IKSys.ikChain ik1 ik3 "IKHISolver"
		)
		catch
		(
			format "Warning: IKSys.ikChain failed: %\n" (getCurrentException())
		)

		-- Wire ExposeTm references (must be set after target nodes exist).
		ex1.exposeNode = ik3
		ex1.localReferenceNode = ik2
		ex1.useParent = true

		ex2.exposeNode = bipRoot
		ex2.useParent = true

		-- RootIK03 rotation constrained to face the pelvis anchor (prevents end-effector spin).
		ik3.rotation.controller = Orientation_Constraint()
		ik3.rotation.controller.appendTarget p1 50.0

		-- Inside IKControl on RootIK01, sub[4] is fk_sub_control (the FK fallback
		-- transform). Set its controller to Link_Constraint -> p1 so the chain start
		-- follows the pelvis anchor when IK is disabled.
		try
		(
			local fkSub = getSubAnim ik1.controller 4
			if fkSub != undefined then
			(
				fkSub.controller = Link_Constraint()
				fkSub.controller.addTarget p1 0
			)
			else
				format "Warning: RootIK01 IKControl has no sub[4] (fk_sub_control)\n"
		)
		catch
		(
			format "Warning: RootIK01 fk_sub_control setup failed: %\n" (getCurrentException())
		)

		-- RootController_Xtras with Attribute Holder + Custom_Attributes CA.
		local rc = makeRootController()

		-- Set up controller tree on RootController + wire all 11 parameter wires.
		_setupRootMotionWires rc ex1 ex2 ikChain bipRoot

		-- Constrain FBX root bone to follow RootController_Xtras. Without this,
		-- the controller animates but nothing in the skeleton picks up its motion.
		-- relative:on so the (root, rc) offset at setup time becomes the baseline
		-- (both should already be at world origin in a clean rig).
		local fbxRoot = getNodeByName "root" exact:true
		if fbxRoot != undefined then
		(
			fbxRoot.position.controller = Position_Constraint()
			fbxRoot.position.controller.relative = on
			fbxRoot[3][1].constraints.appendTarget rc 50

			fbxRoot.rotation.controller = Orientation_Constraint()
			fbxRoot.rotation.controller.relative = on
			fbxRoot[3][2].constraints.appendTarget rc 50
		)
		else
			format "Warning: FBX root bone not found — root won't follow RootController_Xtras.\n"

		addToLayer "99_XtrasBone"        #(p1, ex1, ex2, p2, ik1, ik2, ik3, ikChain) initialOn:false
		addToLayer "10_ControllerBiped"  #(rc)                                       initialOn:true

		-- Force 99_XtrasBone hidden even if the layer already existed.
		local xtrasLayer = LayerManager.getLayerFromName "99_XtrasBone"
		if xtrasLayer != undefined do xtrasLayer.on = false
	)
)
