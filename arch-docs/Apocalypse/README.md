# Apocalypse — Magic of Skyrim, in Enderal

Reference for the replacement plugin in [`src/Apocalypse/`](../../src/Apocalypse/): what the port
had to survive, what is still gapped, and how to prove it works.

| Read | For |
|---|---|
| [`enderal-gap-audit.md`](enderal-gap-audit.md) | **Start here.** What Apocalypse points at that Enderal does not have, what was fixed, and what was deliberately left alone |
| [`spell-test-matrix.md`](spell-test-matrix.md) | A checkbox row per obtainable item — 175 tome spells, 144 scrolls — with console commands, merchants and risk flags. **Generated**; re-run `13-gen-test-matrix.ps1`, do not hand-edit |
| [`../../src/Apocalypse/tools/README.md`](../../src/Apocalypse/tools/README.md) | How the conversion is regenerated against a new Apocalypse version, step by step |
| [`../../src/Apocalypse/Scripts/README.md`](../../src/Apocalypse/Scripts/README.md) | Why the release ships two loose Papyrus scripts that are not ours |

## The two facts that shape everything here

**1. Enderal's engine silently refuses a plugin at `HEDR` form version 1.71.** Apocalypse ships at
1.71, so it never loaded at all — no warning, no log line. That is why this is a *replacement
plugin* rebuilt at 1.70 rather than a patch, and it is not negotiable. Full detail in
[`../../CLAUDE.md`](../../CLAUDE.md), "THE FORM-VERSION CEILING".

**2. Enderal's `Skyrim.esm` is base Enderal, not Bethesda's.** Every conclusion in the gap audit
follows from that. A vanilla FormID resolves only if Enderal happened to keep it, and when it does
it may be a different record — worldspace `00003C` is `Tamriel` in Skyrim and `MQP01Home` in
Enderal.

## Status

The audit and its fixes are **built and verified against the records**; the plugin deserializes,
its header is still 1.70, its census matches, and it introduces no new dangling references. That is
not the same as *working*. The must-pass gate at the top of
[`spell-test-matrix.md`](spell-test-matrix.md) is what establishes the second thing, and it needs
the game launched.
