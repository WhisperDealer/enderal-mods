Scriptname ZenTraits_AeternaVeinsScript extends activemagiceffect  

Import PO3_Events_AME

Spell Property DebuffSpell Auto
Actor Property PlayerRef Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    ApplyDebuff()
    RegisterForLevelIncrease(Self)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    PlayerRef.RemoveSpell(DebuffSpell)
    UnregisterForLevelIncrease(Self)
EndEvent

; reapply on level up
Event OnLevelIncrease(int aiLevel)
    PlayerRef.RemoveSpell(DebuffSpell)
    ApplyDebuff()
EndEvent

Function ApplyDebuff()
    PlayerRef.RestoreAV("Health", 10000) ; fully restore health before applying debuff
    PlayerRef.AddSpell(DebuffSpell)
EndFunction