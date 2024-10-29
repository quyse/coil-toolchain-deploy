{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, toolchain
, fixedsFile ? ./fixeds.json
, fixeds ? lib.importJSON fixedsFile
}:

rec {
  util = import ./util.nix {
    inherit pkgs lib;
  };

  terraform = import ./terraform.nix {
    inherit pkgs lib;
  };

  aws = import ./aws.nix {
    inherit pkgs fixeds terraform;
  };

  cloudflare = import ./cloudflare {
    inherit pkgs fixeds;
  };

  static = import ./static.nix {
    inherit pkgs terraform;
  };

  nginx = import ./nginx.nix {
    inherit pkgs util;
  };

  modules = {
    aws = import ./modules/aws.nix;
    aws-zfs = import ./modules/aws-zfs.nix;
  };

  autoUpdateScript = toolchain.autoUpdateFixedsScript fixedsFile;

  touch = {
    aws-rds-rootCertBundle = aws.rds.rootCertBundle;
    cloudflare-originCertEcc = cloudflare.originCertEcc;

    inherit autoUpdateScript;
  };
}
