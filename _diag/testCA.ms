-- testCA.ms — diagnose which `attributes` syntax variant actually registers.
-- Drag into a fresh Max scene; share full Listener output.

clearListener()

format "===== Variant A: minimal, no version, no ui =====\n"

attributes _DiagA
(
	parameters main
	(
		flag type:#boolean default:true
	)
)

format "  _DiagA = %\n" _DiagA
format "  classOf = %\n" (classOf _DiagA)

format "===== Variant B: with rollout + ui ref =====\n"

attributes _DiagB
(
	parameters main rollout:r
	(
		flag type:#boolean default:true ui:cb1
	)
	rollout r "DiagB"
	(
		checkbox cb1 "Flag"
	)
)

format "  _DiagB = %\n" _DiagB
format "  classOf = %\n" (classOf _DiagB)

format "===== Variant C: with version =====\n"

attributes _DiagC version:1
(
	parameters main
	(
		flag type:#boolean default:true
	)
)

format "  _DiagC = %\n" _DiagC
format "  classOf = %\n" (classOf _DiagC)

format "===== Variant D: with attribID =====\n"

attributes _DiagD attribID:#(0x71234567, 0x12345678)
(
	parameters main
	(
		flag type:#boolean default:true
	)
)

format "  _DiagD = %\n" _DiagD
format "  classOf = %\n" (classOf _DiagD)

format "===== Done =====\n"
