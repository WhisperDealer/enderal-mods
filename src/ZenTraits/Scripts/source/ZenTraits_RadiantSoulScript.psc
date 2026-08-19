Scriptname ZenTraits_RadiantSoulScript extends activemagiceffect  

Actor Property PlayerRef Auto
FormList Property PerksList Auto

Event OnSpellCast(Form akSpell)
    Spell theSpell = akSpell as Spell
    If !theSpell || theSpell.IsHostile() || !PerksList.HasForm(theSpell.GetPerk())
        Return
    EndIf

    Float cost = theSpell.GetMagickaCost()

    PlayerRef.RestoreAV("Stamina", cost)
EndEvent