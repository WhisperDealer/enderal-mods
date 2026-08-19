Scriptname ZenTraits_NightFeverScript extends activemagiceffect

GlobalVariable Property Interval Auto
GlobalVariable Property Magnitude Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    RegisterForSingleUpdateGameTime(Interval.value)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
EndEvent

Event OnUpdateGameTime()
    ArcaneFever.ModFever(Magnitude.value, True)
    RegisterForSingleUpdateGameTime(Interval.value)
EndEvent