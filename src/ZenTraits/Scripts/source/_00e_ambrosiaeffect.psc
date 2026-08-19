Scriptname _00E_AmbrosiaEffect extends activemagiceffect  

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ; ??
	float fMagnitude = - akTarget.GetActorValue("Variable08")
	akTarget.RestoreActorValue("Variable08", fMagnitude)
	
	if akTarget != Game.GetForm(0x14)
		return
	endif

	fMagnitude = ArcaneFever.GetAmbrosiaMod(fMagnitude)
	ArcaneFever.ModFever(fMagnitude, True)
EndEvent