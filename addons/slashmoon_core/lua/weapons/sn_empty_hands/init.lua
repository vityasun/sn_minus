-- Written for: SlashMoon. By: VIKA & Ronni

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')

SWEP.AutoSwitchTo   = false
SWEP.AutoSwitchFrom = false

resource.AddFile( "materials/weapons/empty_hands.vmt" )

resource.AddFile( "materials/models/weapons/rainchu/empty_hands/invisible.vmt" )

function SWEP:GetCapabilities()
	return 0
end
