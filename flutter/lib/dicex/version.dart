// DiceX: DiceX Remote's version (owner, 2026-10-04).
//
// Shown as <RustDesk core>-<DiceX version>.<build>, for example 1.5.0-1.0.11:
//   1.5.0  the RustDesk core this is built on. It is Cargo.toml's version and is never changed
//          by hand: devices send it to each other and compare it (versionCmp(pi.version,
//          '1.2.7') and the like) to decide which features to use. Change it only when syncing
//          from upstream, here and in Cargo.toml together; CI fails when the two differ.
//   1.1    DiceX Remote's own version (1.0 until the redesign of 2026-10-09).
//   11     the DiceX build: one more for every build handed out. Builds 1-10 came before this
//          file and were all labelled 1.5.0.
//
// CI reads both lines (.github/workflows/dicex-*.yml) for file names, Windows file properties
// and Android's versionCode (1000 + build), so this is the one place to bump.

const String kDiceXCoreVersion = '1.5.0';
const String kDiceXVersion = '1.1.12';

/// What people see in About, file names and file properties.
const String kDiceXFullVersion = '$kDiceXCoreVersion-$kDiceXVersion';
