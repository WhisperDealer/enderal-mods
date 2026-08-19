Scriptname _00E_ArkanistenfieberWohltatSCN extends activemagiceffect  

Import ArcaneFever

float fOldAV
float fNewAV
Actor akPlayer

Event OnEffectStart(Actor akTarget, Actor akCaster)
	If akTarget == Game.GetForm(0x14)
		akPlayer = akTarget
		fOldAV = -1*(akPlayer.GetActorValue("LastFlattered"))
	Else
		akPlayer = None
	EndIf
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	If akPlayer
		fNewAV = -1 * (akPlayer.GetActorValue("LastFlattered"))
		ArcaneFever.Notify(fNewAV - fOldAV, 0.0, True)
	EndIf
EndEvent