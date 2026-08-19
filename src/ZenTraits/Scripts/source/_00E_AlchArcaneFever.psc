Scriptname _00E_AlchArcaneFever extends activemagiceffect

Import ArcaneFever

Event OnEffectStart(Actor akTarget, Actor akCaster)

	if akTarget != PlayerRef
		return
	endif

	ModFever(-fMagnitude)

EndEvent

float Property fMagnitude = 2.0 Auto 

Actor Property PlayerRef  Auto  