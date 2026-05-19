-- bipToPoint/lib/makePoint.ms
-- Step 2: Spawn pt_* helper points at each Biped bone, snap them to FBX positions,
-- apply LookAt constraints chained along each limb, then bake to Euler.

struct MakePointTool
(
	bipS,
	pointS,
	fbxS,

	-- Rotate src so its local axes match tgt's rotation.
	fn MRotation src tgt =
	(
		local mRot = (in coordsys src tgt.rotation as EulerAngles) as AngleAxis
		in coordsys src rotate src mRot
	),

	fn arrangePointToFbx =
	(
		for i in 1 to pointS.myAllList.count do
		(
			pointS.myAllList[i].pos = fbxS.myAllList[i].pos
		)
	),

	fn makePointToBip =
	(
		if pointS.myPelvisPT == undefined then
		(
			for i in bipS.myAllList do
			(
				local myPT = point transform:i.transform cross:off axistripod:on size:1.0
				myPT.name = "pt_"+i.name
			)
		)
		-- refresh pointS so it picks up the freshly created nodes
		pointS = pointStruct()
		arrangePointToFbx()
	),

	-- Build a LookAt rig: myPT looks at myTarget, with a helper up-node tracked.
	fn makeArrangePT myPT myTarget =
	(
		local myUp = Point transform:myPT.transform size:0.5 Box:off axistripod:off cross:on centermarker:off
		append pointS.myUpList myUp

		myPT.rotation.controller = LookAt_Constraint()
		myPT.rotation.controller.appendTarget myTarget 100
		myPT.rotation.controller.viewline_length_abs = off
		myPT.rotation.controller.relative = off
		myPT.rotation.controller.StoUP_axis = 1
		myPT.rotation.controller.upnode_world = off
		myPT.rotation.controller.pickupnode = myUp
		myPT.rotation.controller.upnode_axis = 1
	),

	fn makeArrangePTexecute =
	(
		makeArrangePT pointS.mySpinePT pointS.mySpine1PT
		makeArrangePT pointS.mySpine1PT pointS.mySpine2PT
		makeArrangePT pointS.mySpine2PT pointS.myNeckPT
		makeArrangePT pointS.myNeckPT pointS.myHeadPT

		makeArrangePT pointS.myClavicleLPT pointS.myUpperArmLPT
		makeArrangePT pointS.myUpperArmLPT pointS.myForearmLPT
		makeArrangePT pointS.myForearmLPT pointS.myHandLPT
		MRotation pointS.myHandLPT fbxS.myHandL

		pointS.myFinger0LPT.transform = fbxS.myFinger0L.transform
		pointS.myFinger01LPT.transform = fbxS.myFinger01L.transform
		pointS.myFinger1LPT.transform = fbxS.myFinger1L.transform
		pointS.myFinger11LPT.transform = fbxS.myFinger11L.transform
		pointS.myFinger2LPT.transform = fbxS.myFinger2L.transform
		pointS.myFinger21LPT.transform = fbxS.myFinger21L.transform
		pointS.myFinger3LPT.transform = fbxS.myFinger3L.transform
		pointS.myFinger31LPT.transform = fbxS.myFinger31L.transform
		pointS.myFinger4LPT.transform = fbxS.myFinger4L.transform
		pointS.myFinger41LPT.transform = fbxS.myFinger41L.transform

		makeArrangePT pointS.myThighLPT pointS.myCalfLPT
		makeArrangePT pointS.myCalfLPT pointS.myFootLPT
		MRotation pointS.myFootLPT fbxS.myFootL
		coordsys local rotate pointS.myFootLPT (eulerAngles 0 0 180)
		MRotation pointS.myToeLPT fbxS.myToeL

		makeArrangePT pointS.myClavicleRPT pointS.myUpperArmRPT
		makeArrangePT pointS.myUpperArmRPT pointS.myForearmRPT
		makeArrangePT pointS.myForearmRPT pointS.myHandRPT
		MRotation pointS.myHandRPT fbxS.myHandR
		coordsys local rotate pointS.myHandRPT (eulerAngles 0 0 180)

		MRotation pointS.myFinger0RPT fbxS.myFinger0R
		MRotation pointS.myFinger01RPT fbxS.myFinger01R
		MRotation pointS.myFinger1RPT fbxS.myFinger1R
		MRotation pointS.myFinger11RPT fbxS.myFinger11R
		MRotation pointS.myFinger2RPT fbxS.myFinger2R
		MRotation pointS.myFinger21RPT fbxS.myFinger21R
		MRotation pointS.myFinger3RPT fbxS.myFinger3R
		MRotation pointS.myFinger31RPT fbxS.myFinger31R
		MRotation pointS.myFinger4RPT fbxS.myFinger4R
		MRotation pointS.myFinger41RPT fbxS.myFinger41R

		coordsys local rotate pointS.myFinger0RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger01RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger1RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger11RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger2RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger21RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger3RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger31RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger4RPT (eulerAngles 0 0 180)
		coordsys local rotate pointS.myFinger41RPT (eulerAngles 0 0 180)

		makeArrangePT pointS.myThighRPT pointS.myCalfRPT
		makeArrangePT pointS.myCalfRPT pointS.myFootRPT
		MRotation pointS.myFootRPT fbxS.myFootR
		MRotation pointS.myToeRPT fbxS.myToeR
		coordsys local rotate pointS.myToeRPT (eulerAngles 0 0 180)
	),

	-- Bake LookAt result into a plain Euler controller, then drop the temp helper.
	fn deleteArrangePT myPT =
	(
		local myTempPT = Point transform:(matrix3 [1,0,0] [0,1,0] [0,0,1] [0, 0, 0]) size:5 Box:off axistripod:on cross:off centermarker:off
		myTempPT.transform = myPT.transform

		myPT.rotation.controller = Euler_XYZ()
		myPT.transform = myTempPT.transform
		delete myTempPT
	),

	fn deleteArrangePTexecute =
	(
		-- Iterate myAllList[2..end] — index 1 is Pelvis, excluded by design
		for i = 2 to pointS.myAllList.count do
		(
			deleteArrangePT pointS.myAllList[i]
		)
		delete pointS.myUpList
	),

	fn run =
	(
		makePointToBip()
		makeArrangePTexecute()
		deleteArrangePTexecute()
	)
)
