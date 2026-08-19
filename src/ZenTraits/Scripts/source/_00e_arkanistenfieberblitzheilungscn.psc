Scriptname _00E_ArkanistenfieberBlitzheilungSCN extends activemagiceffect  

Import ArcaneFever

float skseMagnitude

event OnInit()
    skseMagnitude = GetMagnitude()
endevent

Event OnEffectFinish(Actor akTarget, Actor akCaster)

	if akTarget != PlayerREF
		return
	endif

	ArcaneFever.ModFever(-skseMagnitude, bVisuals)
	
EndEvent

bool Property bVisuals = false Auto

Actor Property PlayerREF Auto