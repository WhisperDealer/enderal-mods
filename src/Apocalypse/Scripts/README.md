# Apocalypse's own Papyrus

One script, ours, shipped loose under `Scripts/`.

| Script | Attached to | Does |
|---|---|---|
| `ZP_Apoc_TIF_VildasBarter` | INFO `1C1E7E` (topic *"I'd like to see your spell tomes."*) | `akSpeaker.ShowBarterMenu()` - opens Priest Vildas's shop. Same body as FS's Shrouded Mage barter fragments (`TIF__0101E845`). Generated into the tree by `tools/19-vildas-merchant.ps1` |

`compiled/` is committed (a `.gitignore` exception) because CI cannot run the Papyrus compiler.
Recompile after any `.psc` change, with **Enderal's tree first** on the import path (first-wins):

```
PapyrusCompiler.exe src/Apocalypse/Scripts/source/ZP_Apoc_TIF_VildasBarter.psc `
  -i="<papyrusSource.enderal>;<papyrusSource.skse>;<papyrusSource.vanilla>;src/Apocalypse/Scripts/source" `
  -o="src/Apocalypse/Scripts/compiled" -f="TESV_Papyrus_Flags.flg"
```

Up to 1.3.0 this folder held verbatim copies of Enderal's `dgintimidate*` DUMMY stubs; they were
dropped for Enderal 2.1.4.4, which ships no scripts by those names.
