{ pkgs
, lib
}:

rec {
  ref = r: ''''${${r}}'';

  toFile = name: obj: pkgs.writeText "${name}.tf.json" (builtins.toJSON obj);

  toModule = name: obj: let
    file = toFile name obj;
  in pkgs.linkFarm name [
    {
      name = file.name;
      path = file;
    }
  ];
}
