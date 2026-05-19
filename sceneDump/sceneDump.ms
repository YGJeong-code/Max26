-- Compatible: 3ds Max 2024+
/*
sceneDump
Scene structure / controllers / CA / wires text dump
since 2026.05.18
last updated 2026.05.19
by YeonGyun, Jeong
*/

-- Writes a plain-text summary of the current scene (nodes, hierarchy, layers,
-- optional positions/modifiers/rig details) so scene structure can be shared
-- without the binary .max file.

try ( destroyDialog YG_sceneDump ) catch()

rollout YG_sceneDump "Scene Dump" width:300 height:286
(
	edittext et_outPath "" pos:[8,8] width:284 height:20 fieldWidth:284

	checkbox cb_pos         "Include positions"                pos:[8,36]  checked:true
	checkbox cb_modifiers   "Include modifiers"                pos:[8,58]  checked:false
	checkbox cb_layer       "Include layer assignments"        pos:[8,80]  checked:true
	checkbox cb_rigDetails  "Include rig/controller details"   pos:[8,102] checked:true
	checkbox cb_custAttrs   "Include custom attributes"        pos:[8,124] checked:true
	checkbox cb_wires       "Include wire parameters"          pos:[8,146] checked:true
	checkbox cb_openAfter   "Open file after dump"             pos:[8,168] checked:true

	button btn_dump "Dump Scene" pos:[8,194] width:284 height:32

	label  lbl_status "Ready." pos:[8,234] width:284 height:42

	fn computeDefaultOut =
	(
		if maxFilePath != "" then
			(maxFilePath + (getFilenameFile maxFileName) + "_dump.txt")
		else
			(sysInfo.tempdir + "sceneDump.txt")
	)

	fn fmtVec3 v =
	(
		"[" + (formattedPrint v[1] format:".3f") + ", " \
			+ (formattedPrint v[2] format:".3f") + ", " \
			+ (formattedPrint v[3] format:".3f") + "]"
	)

	fn nodeRef n =
	(
		if n == undefined then "<none>" else n.name
	)

	-- Pretty-print a single CA parameter value: nodes -> "$Name", point3 -> "[x, y, z]", else as-string.
	fn formatValue v =
	(
		if v == undefined then "<undefined>"
		else if isKindOf v Node then ("$" + v.name)
		else if isKindOf v Point3 then (fmtVec3 v)
		else if isKindOf v Array then
		(
			local s = "#("
			for i = 1 to v.count do
			(
				if i > 1 do s += ", "
				s += (if isKindOf v[i] Node then ("$" + v[i].name) else (v[i] as string))
			)
			s + ")"
		)
		else (v as string)
	)

	-- Dump custom attributes attached to target (node, modifier, baseObject, etc.).
	fn writeCustAttrs out target indent =
	(
		local count = 0
		try ( count = custAttributes.count target ) catch ()
		if count > 0 do
		(
			for i = 1 to count do
			(
				local ca = undefined
				try ( ca = custAttributes.get target i ) catch ()
				if ca != undefined do
				(
					local caName = "<unnamed>"
					try ( caName = (custAttributes.getDef ca).name ) catch ()
					format "%CA[%]: %\n" indent i caName to:out

					local pnames = #()
					try ( pnames = getPropNames ca ) catch ()
					for pn in pnames do
					(
						local v = undefined
						local ok = true
						try ( v = getProperty ca pn ) catch ( ok = false )
						if ok then
							format "%    %: %\n" indent pn (formatValue v) to:out
						else
							format "%    %: <unreadable>\n" indent pn to:out
					)
				)
			)
		)
	)

	-- Try multiple property/method names since constraint APIs vary across Max versions.
	fn constraintTargetCount c =
	(
		local n = 0
		try ( n = c.constraint_count ) catch ()
		if n == 0 do ( try ( n = c.getNumTargets() ) catch () )
		if n == 0 do ( try ( n = c.target_count ) catch () )
		n
	)

	fn isDefaultController c =
	(
		local cn = (classOf c) as string
		cn == "Bezier_Position" or cn == "Bezier_Rotation" or cn == "Bezier_Scale" or \
		cn == "Linear_Position" or cn == "Linear_Rotation" or cn == "Linear_Scale" or \
		cn == "TCB_Position" or cn == "TCB_Rotation" or cn == "TCB_Scale" or \
		cn == "Euler_XYZ" or cn == "Position_XYZ" or cn == "PRS" or cn == "ScaleXYZ" or \
		cn == "Local_Euler_XYZ"
	)

	-- Print constraint targets if controller is a known constraint type.
	fn writeConstraintTargets out label c =
	(
		local cn = (classOf c) as string
		local count = constraintTargetCount c
		format "    %: % (% targets)\n" label cn count to:out
		if count > 0 do
		(
			for i = 1 to count do
			(
				local tgt = undefined
				try ( tgt = c.getNode i ) catch ()
				local w = 0
				try ( w = c.getWeight i ) catch ()
				format "        [%] % weight:%\n" i (nodeRef tgt) w to:out
			)
		)
		-- LookAt has extra props
		if cn == "LookAt_Constraint" do
		(
			try ( format "        upnode: %\n" (nodeRef c.pickupnode) to:out ) catch ()
			try ( format "        upnode_world: %\n" c.upnode_world to:out ) catch ()
		)
	)

	fn writeRigDetails out node =
	(
		-- Wirecolor (applies to all displayed nodes).
		try ( format "    wirecolor: %\n" node.wirecolor to:out ) catch ()

		-- Transform-level controller (e.g. Link_Constraint, IKChainControl, IKControl).
		-- Skip the default PRS since that's just the standard transform.
		try
		(
			local tc = node.controller
			if tc != undefined do
			(
				local tcn = (classOf tc) as string
				if tcn != "Position_Rotation_Scale" and tcn != "PRS" do
				(
					format "    transformController: %\n" tcn to:out
					if tcn == "Link_Constraint" do
					(
						local n = 0
						try ( n = tc.getNumTargets() ) catch ()
						format "        link targets: %\n" n to:out
						for i = 1 to n do
						(
							local tgt = undefined
							local fr = 0
							try ( tgt = tc.getNode i ) catch ()
							try ( fr = tc.getFrameNo i ) catch ()
							format "            [%] node:%  frame:%\n" i (nodeRef tgt) fr to:out
						)
					)
					-- Walk sub-controllers of non-default transform ctrls so we can see
					-- nested Link_Constraint / Position_Constraint inside e.g. IKControl.
					local subN = 0
					try ( subN = tc.numSubs ) catch ()
					for si = 1 to subN do
					(
						local subA = undefined
						try ( subA = getSubAnim tc si ) catch ()
						if subA != undefined do
						(
							local subNm = ""
							local subCls = "?"
							try ( subNm = (getSubAnimName tc si) as string ) catch ()
							try ( if subA.controller != undefined do subCls = (classOf subA.controller) as string ) catch ()
							format "        sub[%] '%' -> %\n" si subNm subCls to:out
							-- If sub-controller is Link_Constraint, dump targets
							if subCls == "Link_Constraint" do
							(
								try
								(
									local lc = subA.controller
									local ln = lc.getNumTargets()
									for j = 1 to ln do
									(
										local ltgt = undefined
										local lfr = 0
										try ( ltgt = lc.getNode j ) catch ()
										try ( lfr = lc.getFrameNo j ) catch ()
										format "            link[%] node:%  frame:%\n" j (nodeRef ltgt) lfr to:out
									)
								)
								catch ()
							)
						)
					)
				)
			)
		)
		catch ()

		-- Point/ExposeTm helper visual properties (so creation scripts can match).
		local cn = (classOf node) as string
		if cn == "Point" or cn == "ExposeTm" do
		(
			local helperProps = #(#size, #centermarker, #axistripod, #cross, #box, #constantScreenSize, #drawOnTop)
			for p in helperProps do
			(
				try
				(
					local v = getProperty node p
					format "    helper.%: %\n" p v to:out
				)
				catch ()
			)
		)

		-- ExposeTm specifics
		if (classOf node) == ExposeTm do
		(
			try
			(
				format "    exposeNode: %\n" (nodeRef node.exposeNode) to:out
				format "    localReferenceNode: %\n" (nodeRef node.localReferenceNode) to:out
				try ( format "    useParent: %\n" node.useParent to:out ) catch ()
			)
			catch ()
		)

		-- IK chain specifics
		if (classOf node) == IK_Chain_Object do
		(
			local tc = undefined
			try ( tc = node.transform.controller ) catch ()
			if tc != undefined do
			(
				format "    transformController: %\n" (classOf tc) to:out
				try ( format "    startJoint: %\n" (nodeRef tc.startJoint) to:out ) catch ()
				try ( format "    endJoint: %\n" (nodeRef tc.endJoint) to:out ) catch ()
				try ( format "    solver: %\n" tc.solver to:out ) catch ()
			)
		)

		-- Position controller (skip defaults)
		try
		(
			local pc = node.position.controller
			if pc != undefined and not (isDefaultController pc) then
			(
				writeConstraintTargets out "pos.controller" pc
				-- For Position_List / Rotation_List, show active index and sub-controller names
				local pcn = (classOf pc) as string
				if pcn == "Position_List" or pcn == "position_list" do
				(
					try ( format "        active: %  count: %\n" pc.active pc.count to:out ) catch ()
					try
					(
						for i = 1 to pc.count do
						(
							local subC = undefined
							try ( subC = pc[i].controller ) catch ()
							format "        [%] name:'%' ctrl:%\n" i (pc.getName i) (classOf subC) to:out
						)
					)
					catch ()
				)
			)
		)
		catch ()

		-- Rotation controller (skip defaults)
		try
		(
			local rc = node.rotation.controller
			if rc != undefined and not (isDefaultController rc) then
			(
				writeConstraintTargets out "rot.controller" rc
				local rcn = (classOf rc) as string
				if rcn == "Rotation_List" or rcn == "rotation_list" do
				(
					try ( format "        active: %  count: %\n" rc.active rc.count to:out ) catch ()
					try
					(
						for i = 1 to rc.count do
						(
							local subC = undefined
							try ( subC = rc[i].controller ) catch ()
							format "        [%] name:'%' ctrl:%\n" i (rc.getName i) (classOf subC) to:out
						)
					)
					catch ()
				)
			)
		)
		catch ()

		-- Scale controller (rarely interesting but check anyway)
		try
		(
			local sc = node.scale.controller
			if sc != undefined and not (isDefaultController sc) then
				format "    scale.controller: %\n" (classOf sc) to:out
		)
		catch ()
	)

	-- Walk an animatable's subAnim tree looking for a specific target controller.
	-- Returns the dotted path (e.g. "RootController_Xtras.pos.Position_List.Position_XYZ.X_Position")
	-- where the target lives, or undefined if not found within depth limit.
	fn findCtrlPath root target curPath depth maxDepth =
	(
		if root == undefined or depth > maxDepth do return undefined
		if root == target do return curPath
		try
		(
			if root.controller == target do return (curPath + ".controller")
		)
		catch ()
		try
		(
			local nSubs = root.numSubs
			for i = 1 to nSubs do
			(
				local sub = getSubAnim root i
				if sub != undefined do
				(
					local subName = ""
					try ( subName = (getSubAnimName root i) as string ) catch ()
					local subPath = curPath + "." + subName
					if sub == target do return subPath
					try
					(
						if sub.controller == target do return (subPath + ".controller")
					)
					catch ()
					local nested = findCtrlPath sub target subPath (depth + 1) maxDepth
					if nested != undefined do return nested
				)
			)
		)
		catch ()
		undefined
	)

	fn writeNode out node includePos includeMods includeRig includeCAs =
	(
		local parentName = if node.parent != undefined then node.parent.name else "<none>"
		format "- % | class:% | parent:%" node.name (classOf node) parentName to:out
		if includePos then
		(
			format " | pos:%" (fmtVec3 node.transform.position) to:out
		)
		if includeMods or includeCAs then
		(
			try
			(
				if node.modifiers.count > 0 then
				(
					-- Display both class name (e.g. EmptyModifier) and UI name (e.g. "Attribute Holder").
					local mods = for m in node.modifiers collect (((classOf m) as string) + " (name:\"" + m.name + "\")")
					format " | mods:%" mods to:out
				)
			)
			catch ()
		)
		format "\n" to:out

		if includeRig then writeRigDetails out node

		if includeCAs then
		(
			-- Node-level CAs
			try ( writeCustAttrs out node "    " ) catch ()
			-- Modifier-level CAs (Attribute Holder etc. live here)
			try
			(
				for m in node.modifiers do
				(
					local ccount = 0
					try ( ccount = custAttributes.count m ) catch ()
					if ccount > 0 do
					(
						format "    modifier '%' (class:%):\n" m.name (classOf m) to:out
						writeCustAttrs out m "        "
					)
				)
			)
			catch ()
			-- BaseObject CAs (rare but possible)
			try
			(
				local bcount = 0
				try ( bcount = custAttributes.count node.baseObject ) catch ()
				if bcount > 0 do
				(
					format "    baseObject CAs:\n" to:out
					writeCustAttrs out node.baseObject "        "
				)
			)
			catch ()
		)
	)

	on YG_sceneDump open do
	(
		et_outPath.text = computeDefaultOut()
	)

	on btn_dump pressed do
	(
		local outPath = et_outPath.text
		local f = createFile outPath
		if f == undefined then
		(
			lbl_status.text = "Failed to open output:\n" + outPath
		)
		else
		(
			format "== Scene Dump ==\n" to:f
			format "File: %\n" (if maxFileName == "" then "<unsaved>" else maxFileName) to:f
			format "Path: %\n" (if maxFilePath == "" then "<unsaved>" else maxFilePath) to:f
			format "Max version: %\n" (maxVersion()) to:f
			format "Total nodes: %\n\n" objects.count to:f

			-- selection summary
			format "== Selection (%) ==\n" selection.count to:f
			for s in selection do format "- %\n" s.name to:f
			format "\n" to:f

			-- all nodes (flat). parent column lets the reader reconstruct hierarchy.
			format "== Nodes (%) ==\n" objects.count to:f
			for o in objects do
				writeNode f o cb_pos.checked cb_modifiers.checked cb_rigDetails.checked cb_custAttrs.checked

			if cb_wires.checked then
			(
				format "\n== Wire Parameters ==\n" to:f
				local wireClasses = #(Float_Wire, Position_Wire, Rotation_Wire, Point3_Wire, Scale_Wire)
				local totalWires = 0
				for cls in wireClasses do
				(
					local instances = #()
					try ( instances = getClassInstances cls ) catch ()
					if instances.count > 0 do
					(
						format "-- % (% instances) --\n" cls instances.count to:f
						for fw in instances do
						(
							totalWires += 1
							format "  [#%]\n" totalWires to:f

							-- Owner: which scene node holds this wire (filter dependents to Nodes)
							local ownerNodes = #()
							try
							(
								local deps = refs.dependents fw
								ownerNodes = for d in deps where (isKindOf d Node) collect d
								local owners = for n in ownerNodes collect n.name
								format "    ownerNode(s): %\n" owners to:f
							)
							catch ()

							-- Find the exact slave location (where this wire is hooked into the owner's controller tree)
							local slavePath = undefined
							for n in ownerNodes do
							(
								if slavePath == undefined do
								(
									slavePath = findCtrlPath n fw n.name 0 12
								)
							)
							if slavePath != undefined then
								format "    slaveLocation: %\n" slavePath to:f
							else
								format "    slaveLocation: <not found in owner subAnim tree>\n" to:f

							-- Master/slave flags
							try ( format "    isMaster: %  isSlave: %  isTwoWay: %\n" fw.isMaster fw.isSlave fw.isTwoWay to:f ) catch ()
							try ( format "    slaveAnimation: %\n" fw.slaveAnimation to:f ) catch ()

							-- Wire connections via Float_Wire's own methods
							local nw = 0
							try ( nw = fw.numWires ) catch ()
							format "    numWires: %\n" nw to:f
							for i = 1 to nw do
							(
								local parent = undefined
								local subnum = -1
								local coCtl = undefined
								local expr = ""
								try ( parent = fw.getWireParent i ) catch ()
								try ( subnum = fw.getWireSubnum i ) catch ()
								try ( coCtl = fw.getCoController i ) catch ()
								try ( expr = fw.getExprText i ) catch ()
								-- find node owners of the co-controller
								local coOwners = "<?>"
								if coCtl != undefined do
								(
									try
									(
										local coDeps = refs.dependents coCtl
										coOwners = (for d in coDeps where (isKindOf d Node) collect d.name) as string
									)
									catch ()
								)
								format "      [%] parent:% subnum:% coCtrl:% coOwners:% expr:%\n" \
									i parent subnum coCtl coOwners expr to:f
							)
						)
					)
				)
				if totalWires == 0 do format "(no wire controllers in scene)\n" to:f
			)

			if cb_layer.checked then
			(
				format "\n== Layers (%) ==\n" LayerManager.count to:f
				for i = 0 to LayerManager.count - 1 do
				(
					local layer = LayerManager.getLayer i
					local layerNodes = #()
					layer.nodes &layerNodes
					format "- % (on:%, frozen:%, count:%)\n" \
						layer.name layer.on layer.isFrozen layerNodes.count to:f
					for n in layerNodes do format "    %\n" n.name to:f
				)
			)

			close f
			lbl_status.text = "Wrote " + (objects.count as string) + " nodes to:\n" + outPath

			if cb_openAfter.checked then
				shellLaunch outPath ""
		)
	)
)
createDialog YG_sceneDump
