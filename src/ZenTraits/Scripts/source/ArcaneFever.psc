Scriptname ArcaneFever Hidden

ZenTraits_ArcaneFeverScript Function GetScript() Global
    Return (Game.GetFormFromFile(0x802, "Zen Traits.esp") as Quest) as ZenTraits_ArcaneFeverScript
EndFunction

Function ModFever(Float magnitude, Bool bVisual = False) Global
    GetScript().ModFever(magnitude, bVisual)
EndFunction

Function Notify(Float fMagnitude, Float fNewValue = 0.0, Bool bVisual = False) Global
    GetScript().Notify(fMagnitude, fNewValue, bVisual)
EndFunction

Float Function GetAmbrosiaMod(Float fMagnitude) Global
    return GetScript().GetAmbrosiaMod(fMagnitude)
EndFunction