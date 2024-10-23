{ pkgs
, lib
}:

rec {
  ref = r: ''''${${r}}'';

  toFile = name: obj: pkgs.runCommandLocal "${name}.tf.json" {} ''
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
    opentofu = pkgs.opentofu.withPlugins pluginsFun;
    stateDirEscaped = lib.escapeShellArg stateDir;
  in pkgs.writeShellScript "tool" ''
    set -eu
    ln -sf ${moduleFile} ${stateDirEscaped}/main.tf.json
    rm -rf ${stateDirEscaped}/.terraform*
    ${opentofu}/bin/tofu -chdir=${stateDirEscaped} init
    exec ${opentofu}/bin/tofu -chdir=${stateDirEscaped} "$@"
  '';
}
