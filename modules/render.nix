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

      mkResources =
        rules: path: application:
        let
          resources = [ (self.lib.mkNamespace application.namespace) ] ++ application.resources;
        in
        mkYamlFile (lib.concatMap (self.lib.rules.evaluate rules) resources) "${path}/${application.name}.yaml";

      mkApplicationManifest =
        rules: meta: priority: path: application:
        mkYamlFile (
          self.lib.rules.evaluate rules (self.lib.mkApplication { inherit application meta path priority; })
        ) "applications/${application.name}.yaml";

      mkCompartment =
        compartment:
        let
          path = "compartments/${compartment.name}";
          rules = {
            generators = cluster.generators ++ compartment.generators;
            overrides = cluster.overrides ++ compartment.overrides;
            defaults = cluster.defaults ++ compartment.defaults;
          };
        in
        ''
          ${lib.concatMapStringsSep "\n" (
            mkApplicationManifest rules compartment.meta compartment.priority path
          ) compartment.applications}
          mkdir -p "$out/${path}"
          ${lib.concatMapStringsSep "\n" (mkResources rules path) compartment.applications}
        '';
    in
    builtins.toFile "build.sh" ''
      #!/usr/bin/env -S bash -euo pipefail

      out="''${1:?Output dir not specified}"
      mkdir -p "$out/applications" "$out/compartments"
      ${lib.concatMapStringsSep "\n" mkCompartment cluster.compartments}
    '';
}
