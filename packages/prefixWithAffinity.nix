{
  callPackage,
  fetchzip,
  runCommand,
  lndir,
  zstd,
  lib,
  pkgs,

  inputs,
  v3 ? true,
  wine-packages,
  apl-combined,
  ...
}:
let
  layer_3 = callPackage ./basePrefix.nix {
    inherit inputs wine-packages;
  };

  installers = callPackage ./sources.nix { };
  registry-patches = callPackage ./registry-patches.nix { };

  vkd3d = fetchzip {
    url = "https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v3.0.1/vkd3d-proton-3.0.1.tar.zst";
    nativeBuildInputs = [ zstd ];
    hash = "sha256-xHJFtVDD/ZHVHF2Fn7TEEX0fMUWJvujNyNt2Xyw9F7o=";
  };

  wintypes = pkgs.fetchurl {
    name = "wintypes.dll";
    url = "https://raw.githubusercontent.com/ElementalWarrior/wine-wintypes.dll-for-affinity/refs/heads/master/wintypes_shim.dll.so";
    hash = "sha256-pcrlA48/FHpuHolzoa8JfaOP4ohp6/HalCQ9ZL/rv/Y=";
  };

  winmd = pkgs.fetchurl {
    name = "Windows.winmd";
    url = "https://github.com/microsoft/windows-rs/raw/master/crates/libs/bindgen/default/Windows.winmd";
    hash = "sha256-lOtKvda8jv+oup5I9WFWurdJs0AuLl98PRiytasPxys=";
  };

  inherit (wine-packages) wine wineserver winetricks;
in
runCommand "base-prefix-4" { } ''
  set -x -e

  mkdir -p $out
  cp -a ${layer_3}/. $out
  chmod -R +w $out
  export WINEPREFIX="$out"

  cp ${vkd3d}/x64/d3d12.dll "$WINEPREFIX/drive_c/windows/system32"
  cp ${vkd3d}/x64/d3d12core.dll "$WINEPREFIX/drive_c/windows/system32"

  ${lib.getExe wine} regedit /S "${registry-patches.one-vkd3d}"

  ${lib.optionalString v3 ''
    ${lib.getExe lndir} ${installers.v3} "$WINEPREFIX/drive_c/Program Files/"

    pushd "$WINEPREFIX/drive_c/Program Files/Affinity/Affinity"
    cp -r "${apl-combined}/." .
    popd
  ''}

  ${lib.optionalString (!v3) ''
    ${lib.getExe lndir} ${installers.photo} "$WINEPREFIX/drive_c/Program Files/"
    ${lib.getExe lndir} ${installers.designer} "$WINEPREFIX/drive_c/Program Files/"
    ${lib.getExe lndir} ${installers.publisher} "$WINEPREFIX/drive_c/Program Files/"
    cp "${wintypes}" "$WINEPREFIX/drive_c/Program Files/Affinity/wintypes.dll"
    cp "${wintypes}" "$WINEPREFIX/drive_c/Program Files/Affinity/Photo 2/wintypes.dll"
    cp "${wintypes}" "$WINEPREFIX/drive_c/Program Files/Affinity/Publisher 2/wintypes.dll"
    cp "${wintypes}" "$WINEPREFIX/drive_c/Program Files/Affinity/Designer 2/wintypes.dll"
    cp ${winmd} "$WINEPREFIX/drive_c/windows/system32/winmetadata/Windows.winmd"
    echo ${lib.getExe winetricks} --unattended allfonts
  ''}

  ${lib.getExe wineserver} -w

  rm -rf $WINEPREFIX/drive_c/users/nixbld
''
