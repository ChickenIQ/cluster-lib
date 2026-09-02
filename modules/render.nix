{ self, lib, ... }:
{
  flake.lib.renderCluster =
    cluster:
    let
      appSet = self.lib.mkApplicationSet { inherit (cluster) compartments name options; };
      rules = { inherit (cluster) generators overrides defaults; };

      mkYamlFile =
        val: dst:
        let
          src = builtins.toFile (baseNameOf dst) (lib.concatStringsSep "\n---\n" (map builtins.toJSON val));
        in
        ''cp ${src} "$out/${dst}"'';

      mkModule =
        rules: path: m:
        mkYamlFile (lib.concatMap (self.lib.rules.evaluate rules) m.modules) "${path}/${m.name}.yaml";

      mkComp =
        c:
        let
          compartmentRules = {
            generators = cluster.generators ++ c.generators;
            overrides = cluster.overrides ++ c.overrides;
            defaults = cluster.defaults ++ c.defaults;
          };
        in
        ''
          mkdir -p "$out/compartments/${c.name}"
          ${lib.concatMapStringsSep "\n" (mkModule compartmentRules "compartments/${c.name}") c.modules}
        '';
    in
    builtins.toFile "build.sh" ''
      #!/usr/bin/env -S bash -euo pipefail

      out="''${1:?Output dir not specified}"
      mkdir -p "$out/cluster" "$out/compartments"
      ${mkYamlFile [ appSet ] "cluster/cluster-${cluster.name}.yaml"}
      ${lib.concatMapStringsSep "\n" (mkModule rules "cluster") cluster.modules}
      ${lib.concatMapStringsSep "\n" mkComp cluster.compartments}
    '';
}
