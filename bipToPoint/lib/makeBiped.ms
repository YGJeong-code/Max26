-- bipToPoint/lib/makeBiped.ms
-- Step 1: Create a fresh Biped sized to the selected mesh (falls back to 180 if none).

struct MakeBipedTool
(
	fn run =
	(
		local hight_val = 180

		if selection.count == 1 then
			hight_val = $.max.z

		local aa = biped.createNew hight_val -90 [0,0,(hight_val*0.959)] \
			arms:true neckLinks:1 spineLinks:3 legLinks:3 \
			tailLinks:0 ponyTail1Links:0 ponyTail2Links:0 \
			fingers:5 fingerLinks:3 toes:1 toeLinks:1 \
			prop2Exists:True prop3Exists:True \
			ankleAttach:0.23 trianglePelvis:False triangleNeck:True

		aa.controller.figuremode = true
		aa.controller.rootname = "Bip001"

		-- Enable twist links and add 3 to each limb (UE export pipeline expects them).
		-- Properties only writable while figureMode is on.
		aa.controller.twistLinksMode = 1
		aa.controller.UpperArmTwistLinks = 3
		aa.controller.ForeArmTwistLinks  = 3
		aa.controller.ThighTwistLinks    = 3
		aa.controller.CalfTwistLinks     = 3

		max motion mode
		select (biped.getNode aa 13)

		local dis_val = distance $'Bip001 Spine' $'Bip001 Neck'
		local sp_val = dis_val/3

		biped.setTransform $'Bip001 Spine' #scale [sp_val,sp_val,sp_val] off
		biped.setTransform $'Bip001 Spine1' #scale [sp_val,sp_val,sp_val] off
		biped.setTransform $'Bip001 Spine2' #scale [sp_val,sp_val,sp_val] off
		biped.setTransform $'Bip001 L Toe0' #scale [sp_val/3,sp_val/3,sp_val/1.8] off
		biped.setTransform $'Bip001 R Toe0' #scale [sp_val/3,sp_val/3,sp_val/1.8] off
	)
)
