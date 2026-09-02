{ self, lib, ... }:
{
  flake.lib.renderCluster =
    cluster:
    let
      mkYamlFile =
        val: dst:
        let
          src = builtins.toFile (baseNameOf dst) (lib.concatStringsSep "\n---\n" (map builtins.toJSON val));
        in
        ''cp ${src} "$out/${dst}"'';

      mkComp =
        c:
        let
          rules = {
            generators = cluster.generators ++ c.generators;
            overrides = cluster.overrides ++ c.overrides;
            defaults = cluster.defaults ++ c.defaults;
          };
        in
        ''
          mkdir -p "$out/compartments/${c.name}"
          ${lib.concatMapStringsSep "\n" (
            m:
            mkYamlFile (lib.concatMap (self.lib.rules.evaluate rules) m.modules) "compartments/${c.name}/${m.name}.yaml"
          ) c.modules}
        '';

      appSet = self.lib.mkApplicationSet {
        options = cluster.options;
        inherit (cluster) compartments;
      };
    in
    builtins.toFile "build.sh" ''
      #!/usr/bin/env -S bash -euo pipefail

      out="''${1:?Output dir not specified}"
      mkdir -p "$out/applications" "$out/compartments"
      ${mkYamlFile [ appSet ] "applications/applicationset.yaml"}
      ${lib.concatMapStringsSep "\n" mkComp cluster.compartments}
    '';
}
