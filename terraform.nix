{ pkgs
, lib
}:

rec {
  ref = r: ''''${${r}}'';

  toFile = name: obj: pkgs.runCommand "${name}.tf.json" {} ''
    ${pkgs.jq}/bin/jq < ${pkgs.writeText "${name}.tf.json" (builtins.toJSON obj)} > $out
  '';

  toModule = name: obj: let
    file = toFile name obj;
  in pkgs.linkFarm name [
    {
      name = file.name;
      path = file;
    }
  ];

  tool =
  { moduleFile
  , pluginsFun ? (standardPlugins: [])
  , stateDir ? "./state"
  }: let
    terraform = pkgs.terraform.withPlugins pluginsFun;
    stateDirEscaped = lib.escapeShellArg stateDir;
  in pkgs.writeShellScript "tool" ''
    set -eu
    ln -sf ${moduleFile} ${stateDirEscaped}/main.tf.json
    rm -rf ${stateDirEscaped}/.terraform*
    ${terraform}/bin/terraform -chdir=${stateDirEscaped} init
    exec ${terraform}/bin/terraform -chdir=${stateDirEscaped} "$@"
  '';
}
