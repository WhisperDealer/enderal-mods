Scriptname _00E_IncreaseArcaneFeverFFTarget extends activemagiceffect

Import ArcaneFever

Float fMagnitude

Event OnEffectStart(Actor akTarget, Actor akCaster)
    fMagnitude = GetMagnitude()
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	If akCaster != PlayerREF
		return
	endif

    ArcaneFever.ModFever(-fMagnitude)
EndEvent

Actor Property PlayerREF Auto
