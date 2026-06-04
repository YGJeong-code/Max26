-- Compatible: 3ds Max 2024+
-- bipToPoint/lib/footContact.ms
-- Custom Attribute on FBX root bone exposing live binary foot-contact flags:
--   ground_z   — user-editable Z value treated as ground (default 8.8)
--   threshold  — user-editable contact band in cm (default 2.0)
--   contact_l  — live: 1.0 if (foot_l.z - ground_z) <= threshold, else 0.0
--   contact_r  — live: same for foot_r
-- All four params are #float so they animate / export to FBX as named curves
-- on the root node.

-- CA def captured into a global because bare name binding doesn't work in this
-- Max env (same as rootMotion.ms).
global gFootContactCA

gFootContactCA = attributes Foot_Contact version:1
(
	parameters main rollout:rollMain
	(
		ground_z  type:#float default:8.8 animatable:true ui:spn_ground
		threshold type:#float default:2.0 animatable:true ui:spn_thresh
		contact_l type:#float default:0.0 animatable:true
		contact_r type:#float default:0.0 animatable:true
	)

	rollout rollMain "Foot Contact"
	(
		spinner spn_ground "Ground Z:"  pos:[8,8]  fieldwidth:60 range:[-100000, 100000, 8.8] type:#float scale:0.1
		spinner spn_thresh "Threshold:" pos:[8,28] fieldwidth:60 range:[0.0, 10000, 2.0] type:#float scale:0.1
		label lbl_l "L contact:" pos:[8,52]  width:60
		label val_l "0.000"      pos:[72,52] width:80
		label lbl_r "R contact:" pos:[8,70]  width:60
		label val_r "0.000"      pos:[72,70] width:80

		timer tmr_live interval:100 active:false

		fn refreshLabels =
		(
			val_l.text = formattedPrint contact_l format:".3f"
			val_r.text = formattedPrint contact_r format:".3f"
		)

		on rollMain open do
		(
			refreshLabels()
			tmr_live.active = true
		)
		on rollMain close do
		(
			tmr_live.active = false
		)
		on tmr_live tick  do refreshLabels()
		on spn_ground changed v do refreshLabels()
		on spn_thresh changed v do refreshLabels()
	)
)

struct FootContactTool
(
	-- Normalised CA def name (Name -> string for safe comparison).
	fn _caDefName ca =
	(
		local nm = ""
		try
		(
			local def = custAttributes.getDef ca
			if def != undefined do nm = (def.name as string)
		)
		catch ()
		nm
	),

	-- Wire a Float_Script controller onto the named CA param. The script reads
	-- the foot's world Z and compares (foot.z - ground_z) <= threshold, both
	-- pulled live from the root CA so the user can tune Ground Z / Threshold
	-- in the Modify panel and contact values update immediately.
	fn _wireContact rootObj paramName footNode =
	(
		local ctrl = Float_Script()
		ctrl.AddNode "footN" footNode
		ctrl.AddNode "rootN" rootObj
		ctrl.SetExpression "if (footN.transform.position.z - rootN.Foot_Contact.ground_z) <= rootN.Foot_Contact.threshold then 1.0 else 0.0"

		local ok = false
		try
		(
			rootObj.Foot_Contact[paramName as name].controller = ctrl
			ok = true
		)
		catch ()

		if not ok do
			format "FootContact: failed to wire %\n" paramName
		ok
	),

	fn remove rootObj =
	(
		-- Delete the Foot_Contact CA from any location it might live on (node
		-- itself or baseobject). Iterating in reverse keeps indices valid.
		local removed = 0
		local targets = #(rootObj, rootObj.baseObject)
		for tgt in targets do
		(
			local cnt = 0
			try ( cnt = custAttributes.count tgt ) catch ()
			for i = cnt to 1 by -1 do
			(
				local ca = undefined
				try ( ca = custAttributes.get tgt i ) catch ()
				if ca != undefined and (_caDefName ca) == "Foot_Contact" do
				(
					try ( custAttributes.delete tgt i; removed += 1 ) catch ()
				)
			)
		)
		format "Foot Contact: removed % CA instance(s)\n" removed
	),

	fn run rootObj footL footR groundZInitial thresholdInitial =
	(
		-- Clean re-run.
		remove rootObj

		custAttributes.add rootObj gFootContactCA

		-- Seed user-editable ground / threshold values.
		try ( rootObj.Foot_Contact.ground_z  = groundZInitial )  catch ()
		try ( rootObj.Foot_Contact.threshold = thresholdInitial ) catch ()

		_wireContact rootObj "contact_l" footL
		_wireContact rootObj "contact_r" footR

		format "Foot Contact set up. ground_z=% threshold=% (foot_l.z=% foot_r.z=%)\n" \
			groundZInitial thresholdInitial footL.transform.position.z footR.transform.position.z
	)
)
