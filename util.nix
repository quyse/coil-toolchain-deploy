{ pkgs
, lib
}:

rec {
  remoteRunScript = script: pkgs.writeShellScript "remote-run" ''
    set -eu
    REMOTE="''${1:?first argument required: user@server}"
    shift
    echo "Copying script closure to ''${REMOTE}..." >&2
    nix-copy-closure --to "''${REMOTE}" ${lib.escapeShellArg script}
    echo "Executing remote script on ''${REMOTE}..." >&2
    ssh "''${REMOTE}" ${lib.escapeShellArg script} "$@"
    echo "remote run exit code: $?" >&2
  '';

  pinScript = path: obj: let
    hash = builtins.hashString "sha256" path;
    escapedPath = lib.escapeShellArg path;
  in pkgs.writeShellScript "pin" ''
    set -eu
    ln -sfT ${lib.escapeShellArg obj} ${escapedPath}
    ln -sfT ${escapedPath} /nix/var/nix/gcroots/auto/pin-${hash}
  '';
}
