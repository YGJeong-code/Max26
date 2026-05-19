-- Compatible: 3ds Max 2024+
-- bipToPoint/lib/bipAlign.ms
-- Step 3: With Biped in figure mode, drive each Biped bone's pos/rot/scale from the
-- corresponding pt_* helper. Also builds the weapon (prop) bones in the hands.

struct BipAlignTool
(
	bipS,
	pointS,
	fbxS,

	-- Rotate src to match tgt's rotation.
	fn MRotation src tgt =
	(
		local mRot = (in coordsys src tgt.rotation as EulerAngles) as AngleAxis
		in coordsys src rotate src mRot
	),

	-- Match Biped bone tbip to span from dis1 to dis2 (rotation + length).
	-- dis2 defaults to dis1.parent if not supplied.
	fn align_bip tbip dis1 dis2 =
	(
		if tbip != undefined then
		(
			if dis2 == undefined then dis2 = dis1.parent
			local get_dis = (distance dis1 dis2)
			biped.setTransform tbip #pos (dis1.transform.position) false
			MRotation tbip dis1

			local bipScale = biped.getTransform tbip #scale
			biped.setTransform tbip #scale [get_dis, bipScale[2], bipScale[3]] false
		)
	),

	-- Older variant: rotate via #rotation and use uniform scale. Used for prop bones.
	fn align_bip_old tbip dis1 dis2 =
	(
		if tbip != undefined then
		(
			if dis2 == undefined then dis2 = dis1.parent
			local get_dis = (distance dis1 dis2)
			biped.setTransform tbip #pos (dis1.transform.position) false
			biped.setTransform tbip #rotation (dis1.transform.rotation) false
			biped.setTransform tbip #scale [get_dis, get_dis, get_dis] false
		)
	),

	fn makeWeaponBone =
	(
		local myName = "Bip001"
		local myPropL = execute ("$" + myName + "Prop2")
		local myPropR = execute ("$" + myName + "Prop1")

		local myHandL = bipS.myHandL
		local myHandR = bipS.myHandR

		-- Reuse existing weapon_l/r if user placed them; otherwise spawn at the hand.
		local myHandLPT = getNodeByName "weapon_l"
		if myHandLPT == undefined then
		(
			myHandLPT = point transform:myHandL.transform cross:off axistripod:on size:1.0
			myHandLPT.name = "weapon_l"
		)

		local myHandRPT = getNodeByName "weapon_r"
		if myHandRPT == undefined then
		(
			myHandRPT = point transform:myHandR.transform cross:off axistripod:on size:1.0
			myHandRPT.name = "weapon_r"
		)

		-- end point along local Z, offset by 20
		local localZ = normalize (myHandLPT.transform.row3)
		local myHandLEndPT = point transform:myHandL.transform cross:off axistripod:on size:1.0
		myHandLEndPT.pos += localZ * 20

		localZ = normalize (myHandRPT.transform.row3)
		local myHandREndPT = point transform:myHandR.transform cross:off axistripod:on size:1.0
		myHandREndPT.pos += localZ * 20

		align_bip_old myPropL myHandLPT myHandLEndPT
		align_bip_old myPropR myHandRPT myHandREndPT

		delete #(myHandLEndPT, myHandREndPT)

		-- constrain weapon helper to prop bone
		myHandLPT.rotation.controller = Orientation_Constraint ()
		myHandLPT.rotation.controller.relative = on
		myHandLPT[3][2].constraints.appendTarget myPropL 50

		myHandLPT.position.controller = Position_Constraint ()
		myHandLPT.position.controller.relative = on
		myHandLPT[3][1].constraints.appendTarget myPropL 50

		myHandRPT.rotation.controller = Orientation_Constraint ()
		myHandRPT.rotation.controller.relative = on
		myHandRPT[3][2].constraints.appendTarget myPropR 50

		myHandRPT.position.controller = Position_Constraint ()
		myHandRPT.position.controller.relative = on
		myHandRPT[3][1].constraints.appendTarget myPropR 50

		-- parent under FBX hand bones (assumes hand_l / hand_r exist)
		myHandLPT.parent = $hand_l
		myHandRPT.parent = $hand_r

		myPropL.boxmode = on
		myPropR.boxmode = on

		biped.setTransform myPropL #scale ([10, 10, 25]) True
		biped.setTransform myPropR #scale ([10, 10, 25]) True
	),

	fn bipToPoint =
	(
		-- ensure figure mode
		local biped_ctrl = bipS.myBip.controller
		biped_ctrl.figureMode = true

		-- com: align Biped root to pelvis XY, leg Z
		biped.setTransform bipS.myBip #pos \
			[pointS.myPelvisPT.transform.pos.x, pointS.myPelvisPT.transform.pos.y, pointS.myThighLPT.transform.pos.z] \
			True

		-- pelvis
		local temp = distance pointS.myPelvisPT pointS.mySpinePT
		local temp2 = distance bipS.myBip pointS.myThighLPT
		biped.setTransform bipS.myPelvis #scale ([temp*2,temp*2,temp2*2]) True

		-- spine
		align_bip bipS.mySpine pointS.mySpinePT pointS.mySpine1PT
		align_bip bipS.mySpine1 pointS.mySpine1PT pointS.mySpine2PT
		align_bip bipS.mySpine2 pointS.mySpine2PT pointS.myNeckPT

		-- neck
		align_bip bipS.myNeck pointS.myNeckPT pointS.myHeadPT

		-- arm L
		align_bip bipS.myClavicleL pointS.myClavicleLPT pointS.myUpperArmLPT
		align_bip bipS.myUpperArmL pointS.myUpperArmLPT pointS.myForearmLPT
		align_bip bipS.myForearmL pointS.myForearmLPT pointS.myHandLPT
		align_bip bipS.myHandL pointS.myHandLPT pointS.myFinger2LPT

		-- fingers L
		align_bip bipS.myFinger0L pointS.myFinger0LPT pointS.myFinger01LPT
		align_bip bipS.myFinger01L pointS.myFinger01LPT pointS.myFinger02LPT

		align_bip bipS.myFinger1L pointS.myFinger1LPT pointS.myFinger11LPT
		align_bip bipS.myFinger11L pointS.myFinger11LPT pointS.myFinger12LPT

		align_bip bipS.myFinger2L pointS.myFinger2LPT pointS.myFinger21LPT
		align_bip bipS.myFinger21L pointS.myFinger21LPT pointS.myFinger22LPT

		align_bip bipS.myFinger3L pointS.myFinger3LPT pointS.myFinger31LPT
		align_bip bipS.myFinger31L pointS.myFinger31LPT pointS.myFinger32LPT

		align_bip bipS.myFinger4L pointS.myFinger4LPT pointS.myFinger41LPT
		align_bip bipS.myFinger41L pointS.myFinger41LPT pointS.myFinger42LPT

		-- leg L
		align_bip bipS.myThighL pointS.myThighLPT pointS.myCalfLPT
		align_bip bipS.myCalfL pointS.myCalfLPT pointS.myFootLPT

		biped.setTransform bipS.myFootL #pos (pointS.myFootLPT.transform.pos) True
		biped.setTransform bipS.myFootL #rotation (pointS.myFootLPT.transform.rotation) True
		temp = distance pointS.myFootLPT pointS.myToeLPT
		temp2 = pointS.myFootLPT.pos[3] - pointS.myToeLPT.pos[3]
		biped.setTransform bipS.myFootL #scale ([temp2,temp,temp2]) True

		biped.setTransform bipS.myToeL #pos (pointS.myToeLPT.transform.pos) True
		biped.setTransform bipS.myToeL #rotation (pointS.myToeLPT.transform.rotation) True

		-- arm R
		align_bip bipS.myClavicleR pointS.myClavicleRPT pointS.myUpperArmRPT
		align_bip bipS.myUpperArmR pointS.myUpperArmRPT pointS.myForearmRPT
		align_bip bipS.myForearmR pointS.myForearmRPT pointS.myHandRPT
		align_bip bipS.myHandR pointS.myHandRPT pointS.myFinger2RPT

		-- fingers R
		align_bip bipS.myFinger0R pointS.myFinger0RPT pointS.myFinger01RPT
		align_bip bipS.myFinger01R pointS.myFinger01RPT pointS.myFinger02RPT

		align_bip bipS.myFinger1R pointS.myFinger1RPT pointS.myFinger11RPT
		align_bip bipS.myFinger11R pointS.myFinger11RPT pointS.myFinger12RPT

		align_bip bipS.myFinger2R pointS.myFinger2RPT pointS.myFinger21RPT
		align_bip bipS.myFinger21R pointS.myFinger21RPT pointS.myFinger22RPT

		align_bip bipS.myFinger3R pointS.myFinger3RPT pointS.myFinger31RPT
		align_bip bipS.myFinger31R pointS.myFinger31RPT pointS.myFinger32RPT

		align_bip bipS.myFinger4R pointS.myFinger4RPT pointS.myFinger41RPT
		align_bip bipS.myFinger41R pointS.myFinger41RPT pointS.myFinger42RPT

		-- leg R
		align_bip bipS.myThighR pointS.myThighRPT pointS.myCalfRPT
		align_bip bipS.myCalfR pointS.myCalfRPT pointS.myFootRPT

		biped.setTransform bipS.myFootR #pos (pointS.myFootRPT.transform.pos) True
		biped.setTransform bipS.myFootR #rotation (pointS.myFootRPT.transform.rotation) True
		temp = distance pointS.myFootRPT pointS.myToeRPT
		temp2 = pointS.myFootRPT.pos[3] - pointS.myToeRPT.pos[3]
		biped.setTransform bipS.myFootR #scale ([temp2,temp,temp2]) True

		biped.setTransform bipS.myToeR #pos (pointS.myToeRPT.transform.pos) True
		biped.setTransform bipS.myToeR #rotation (pointS.myToeRPT.transform.rotation) True

		-- boxmode
		for i in bipS.myAllList do i.boxmode = on

		-- weapon props
		makeWeaponBone()
	),

	fn deletePT =
	(
		delete pointS.myAllList
	),

	fn run =
	(
		bipToPoint()
		deletePT()
	)
)
