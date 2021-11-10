{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, toolchain
, fixedsFile ? ./fixeds.json
, fixeds ? lib.importJSON fixedsFile
}:

rec {
  aws = import ./aws.nix {
    inherit pkgs lib fixeds;
  };

  autoUpdateScript = toolchain.autoUpdateFixedsScript fixedsFile;

  touch = {
    aws-rds-rootCertBundle = aws.rds.rootCertBundle;

    inherit autoUpdateScript;
  };
}
