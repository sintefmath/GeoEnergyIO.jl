# Deck keyword refactor follow-up

These behaviors were present before the refactor and are outside its scope.

- The header lexer takes the first word and drops punctuation. `MULTX-`,
  `MULTY-` and `MULTZ-` therefore reach the positive-direction definitions.
  Several negative-direction `KRW` and `KRWR` declarations also have a leading
  colon in their registered spelling and are unreachable from a deck header.
- `skip_kw!` previously described finite counts above one as fixed-length
  skips. Its implementation reads through an empty record for all counts
  other than zero or one. The parser manual now describes the implemented behavior.
- `WCONINJ` carries its unit for field 12 from one record to the next within
  a keyword block. A water well after a gas or oil well can inherit the
  previous well's conversion.
- The `HEAD` branch for `AQUCHWAT` passes an undefined identifier when it
  tries to emit its support message.
- The keyword fallback for unlisted grid arrays reassigns the return value
  of the box write to the deck dictionary. Inside a partial `BOX`, this can
  replace a whole-grid array with just the values from the box.
- The local root manifest selected Jutul 0.4.16. That version lacks
  `Jutul.MeshQualityControl`, which the full GeoEnergyIO test suite imports.
