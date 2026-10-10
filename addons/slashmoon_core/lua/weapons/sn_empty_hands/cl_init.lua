-- Written for: SlashMoon. By: VIKA & Ronni

include( 'shared.lua' )

SWEP.PrintName = "#weapon_empty_hands"

SWEP.Slot             = 0
SWEP.SlotPos          = 1

SWEP.DrawAmmo         = false
SWEP.DrawCrosshair    = true 

SWEP.WepSelectIcon    = surface.GetTextureID( "weapons/empty_hands" )
SWEP.BounceWeaponIcon = false
SWEP.DrawWeaponInfoBox = false

SWEP.ViewModelFOV = 25 

-- Обрати внимание: 3-й аргумент true, чтобы настройка сохранялась после перезахода
CreateClientConVar( "emptyhands_showcrosshair", "1", true, false )

function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )

	surface.SetDrawColor( 255, 255, 255, alpha )
	surface.SetTexture( self.WepSelectIcon )

	local fsin = 0

	if ( self.BounceWeaponIcon == true ) then
		fsin = math.sin( CurTime() * 10 ) * 5
	end

	y = y + 10
	x = x + 10
	wide = wide - 20

	surface.DrawTexturedRect( x + (fsin), y - (fsin),  wide-fsin*2 , ( wide / 2 ) + (fsin) )
	self:PrintWeaponInfo( x + wide + 20, y + tall * 0.95, alpha )
end
