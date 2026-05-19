-- bipToPoint/lib/structs.ms
-- Node-reference structs for Biped, Point helpers, and FBX skeleton.
-- All bone mapping lives in `b2p_BoneMap`; the three structs are generated
-- dynamically (via execute) from it. myAllList is built by referencing the
-- already-resolved fields, so each node is looked up exactly once.
-- Lookup choice:
--   Biped + Point helpers: execute("$"+name)  — Biped names contain spaces
--     ("Bip001 Pelvis"), so we rely on $-syntax pattern matching, which
--     ignores spaces and case.
--   FBX bones: getNodeByName name exact:true  — lowercase/underscored, exact
--     match is faster and safer.

-- Main bone map. Each row: #(field-key, Biped suffix, FBX name).
-- Order here drives the order of myAllList.
global b2p_BoneMap = #(
	#("Pelvis",    "Pelvis",    "pelvis"),
	#("Spine",     "Spine",     "spine_02"),
	#("Spine1",    "Spine1",    "spine_03"),
	#("Spine2",    "Spine2",    "spine_04"),
	#("Neck",      "Neck",      "neck_01"),
	#("Head",      "Head",      "head"),
	#("ClavicleL",    "LClavicle",    "clavicle_l"),
	#("UpperArmL",    "LUpperArm",    "upperarm_l"),
	#("UpArmTwist1L", "LUpArmTwist1", "upperarm_twist_01_l"),
	#("UpArmTwist2L", "LUpArmTwist2", "upperarm_twist_02_l"),
	#("ForearmL",     "LForearm",     "lowerarm_l"),
	#("ForeTwist1L",  "LForeTwist1",  "lowerarm_twist_02_l"),
	#("ForeTwist2L",  "LForeTwist2",  "lowerarm_twist_01_l"),
	#("HandL",        "LHand",        "hand_l"),
	#("Finger0L",  "LFinger0",  "thumb_01_l"),
	#("Finger01L", "LFinger01", "thumb_02_l"),
	#("Finger02L", "LFinger02", "thumb_03_l"),
	#("Finger1L",  "LFinger1",  "index_01_l"),
	#("Finger11L", "LFinger11", "index_02_l"),
	#("Finger12L", "LFinger12", "index_03_l"),
	#("Finger2L",  "LFinger2",  "middle_01_l"),
	#("Finger21L", "LFinger21", "middle_02_l"),
	#("Finger22L", "LFinger22", "middle_03_l"),
	#("Finger3L",  "LFinger3",  "ring_01_l"),
	#("Finger31L", "LFinger31", "ring_02_l"),
	#("Finger32L", "LFinger32", "ring_03_l"),
	#("Finger4L",  "LFinger4",  "pinky_01_l"),
	#("Finger41L", "LFinger41", "pinky_02_l"),
	#("Finger42L", "LFinger42", "pinky_03_l"),
	#("ThighL",        "LThigh",        "thigh_l"),
	#("ThighTwist1L",  "LThighTwist1",  "thigh_twist_01_l"),
	#("ThighTwist2L",  "LThighTwist2",  "thigh_twist_02_l"),
	#("CalfL",         "LCalf",         "calf_l"),
	#("CalfTwist1L",   "LCalfTwist1",   "calf_twist_02_l"),
	#("CalfTwist2L",   "LCalfTwist2",   "calf_twist_01_l"),
	#("FootL",         "LFoot",         "foot_l"),
	#("ToeL",          "LToe0",         "ball_l"),
	#("ClavicleR",    "RClavicle",    "clavicle_r"),
	#("UpperArmR",    "RUpperArm",    "upperarm_r"),
	#("UpArmTwist1R", "RUpArmTwist1", "upperarm_twist_01_r"),
	#("UpArmTwist2R", "RUpArmTwist2", "upperarm_twist_02_r"),
	#("ForearmR",     "RForearm",     "lowerarm_r"),
	#("ForeTwist1R",  "RForeTwist1",  "lowerarm_twist_02_r"),
	#("ForeTwist2R",  "RForeTwist2",  "lowerarm_twist_01_r"),
	#("HandR",        "RHand",        "hand_r"),
	#("Finger0R",  "RFinger0",  "thumb_01_r"),
	#("Finger01R", "RFinger01", "thumb_02_r"),
	#("Finger02R", "RFinger02", "thumb_03_r"),
	#("Finger1R",  "RFinger1",  "index_01_r"),
	#("Finger11R", "RFinger11", "index_02_r"),
	#("Finger12R", "RFinger12", "index_03_r"),
	#("Finger2R",  "RFinger2",  "middle_01_r"),
	#("Finger21R", "RFinger21", "middle_02_r"),
	#("Finger22R", "RFinger22", "middle_03_r"),
	#("Finger3R",  "RFinger3",  "ring_01_r"),
	#("Finger31R", "RFinger31", "ring_02_r"),
	#("Finger32R", "RFinger32", "ring_03_r"),
	#("Finger4R",  "RFinger4",  "pinky_01_r"),
	#("Finger41R", "RFinger41", "pinky_02_r"),
	#("Finger42R", "RFinger42", "pinky_03_r"),
	#("ThighR",        "RThigh",        "thigh_r"),
	#("ThighTwist1R",  "RThighTwist1",  "thigh_twist_01_r"),
	#("ThighTwist2R",  "RThighTwist2",  "thigh_twist_02_r"),
	#("CalfR",         "RCalf",         "calf_r"),
	#("CalfTwist1R",   "RCalfTwist1",   "calf_twist_02_r"),
	#("CalfTwist2R",   "RCalfTwist2",   "calf_twist_01_r"),
	#("FootR",         "RFoot",         "foot_r"),
	#("ToeR",          "RToe0",         "ball_r")
)

-- End-cap bones used only by pointStruct (Bip naming, no FBX counterpart needed).
global b2p_PointEndBones = #(
	"HeadEnd",
	"LFinger0End", "LFinger1End", "LFinger2End", "LFinger3End", "LFinger4End",
	"LToeEnd",
	"RFinger0End", "RFinger1End", "RFinger2End", "RFinger3End", "RFinger4End",
	"RToeEnd"
)

-- Build the three struct definitions from b2p_BoneMap.
fn _b2p_buildStructs =
(
	local s, fieldsList

	-- ---- bipStruct ---- (Biped names have spaces — use execute "$..." )
	s = "struct bipStruct (\n"
	s += "    myName = \"Bip001\",\n"
	s += "    myBip = execute (\"$\" + myName),\n"
	fieldsList = ""
	for e in b2p_BoneMap do
	(
		local fname = "my" + e[1]
		s += "    " + fname + " = execute (\"$\" + myName + \"" + e[2] + "\"),\n"
		if fieldsList != "" do fieldsList += ", "
		fieldsList += fname
	)
	s += "    myAllList = #(" + fieldsList + ")\n"
	s += ")\n"
	execute s

	-- ---- pointStruct ---- (pt_ prefix + Biped suffix — also spaces, use $)
	s = "struct pointStruct (\n"
	s += "    myName = \"Bip001\",\n"
	s += "    myBipPT = execute (\"$pt_\" + myName),\n"
	fieldsList = ""
	for e in b2p_BoneMap do
	(
		local fname = "my" + e[1] + "PT"
		s += "    " + fname + " = execute (\"$pt_\" + myName + \"" + e[2] + "\"),\n"
		if fieldsList != "" do fieldsList += ", "
		fieldsList += fname
	)
	for n in b2p_PointEndBones do
		s += "    my" + n + "PT = execute (\"$pt_\" + myName + \"" + n + "\"),\n"
	s += "    myAllList = #(" + fieldsList + "),\n"
	s += "    myUpList = #()\n"
	s += ")\n"
	execute s

	-- ---- fbxStruct ---- (FBX names lowercased/underscored, exact lookup OK)
	s = "struct fbxStruct (\n"
	s += "    myName = \"\",\n"
	s += "    myBip = getNodeByName \"root\" exact:true,\n"
	fieldsList = ""
	for e in b2p_BoneMap do
	(
		local fname = "my" + e[1]
		s += "    " + fname + " = getNodeByName (myName + \"" + e[3] + "\") exact:true,\n"
		if fieldsList != "" do fieldsList += ", "
		fieldsList += fname
	)
	s += "    myAllList = #(" + fieldsList + ")\n"
	s += ")\n"
	execute s
)

_b2p_buildStructs()
