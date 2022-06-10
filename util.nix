{ pkgs
, lib
}:

rec {
  remoteRunScript = script: pkgs.writeShellScript "remote-run" ''
    set -eu
    REMOTE="''${1:?first argument required: user@server}"
    echo "Copying script closure to ''${REMOTE}..."
    nix-copy-closure --to "''${REMOTE}" "${script}"
    echo "Executing remote script on ''${REMOTE}..."
    ssh "''${REMOTE}" "${script}"
    echo "remote run exit code: $?"
  '';

  pinScript = path: obj: let
    hash = builtins.hashString "sha256" path;
    escapedPath = lib.escapeShellArg path;
  in pkgs.writeShellScript "pin" ''
    set -eu
    ln -sf ${lib.escapeShellArg obj} ${escapedPath}
    ln -sf ${escapedPath} /nix/var/nix/gcroots/auto/pin-${hash}
  '';
}
