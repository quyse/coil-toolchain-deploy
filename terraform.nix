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
}
