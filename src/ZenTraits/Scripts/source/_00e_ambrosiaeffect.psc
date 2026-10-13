Scriptname _00E_AmbrosiaEffect extends activemagiceffect  

Event OnEffectStart(Actor akTarget, Actor akCaster)
	float fMagnitude = Self.GetMagnitude()
	
	if akTarget != Game.GetForm(0x14)
		return
	endif

	fMagnitude = ArcaneFever.GetAmbrosiaMod(fMagnitude)
	ArcaneFever.ModFever(fMagnitude, True)
EndEvent