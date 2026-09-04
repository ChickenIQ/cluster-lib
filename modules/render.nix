{ self, lib, ... }:
{
  flake.lib.render =
    cluster:
    let
      compartments = map (
        compartment:
        let
          applyRules = self.lib.rules.eval {
            overrides = cluster.overrides ++ compartment.overrides;
            defaults = cluster.defaults ++ compartment.defaults;
          };
        in
        {
          inherit (compartment) name;
          applications = map (
            application: self.lib.app.eval { inherit application applyRules compartment; }
          ) compartment.applications;
        }
      ) cluster.compartments;

      mkYamlFile =
        doc: dst:
        let
          src = builtins.toFile (baseNameOf dst) (lib.concatMapStringsSep "\n---\n" builtins.toJSON doc);
        in
        ''cp ${src} "$out/${dst}"'';

      renderApp = app: ''
        ${mkYamlFile [ app.manifest ] app.manifestPath}
        ${mkYamlFile ([ app.namespace ] ++ app.resources) app.resourcePath}
      '';

      renderCompartment = compartment: ''
        mkdir -p "$out/compartments/${compartment.name}"
        ${lib.concatMapStringsSep "\n" renderApp compartment.applications}
      '';
    in
    {
      buildScript = builtins.toFile "build.sh" ''
        #!/bin/sh
        set -euo pipefail

        out="''${1:?Output dir not specified}"
        mkdir -p "$out/applications" "$out/compartments"
        ${lib.concatMapStringsSep "\n" renderCompartment compartments}
      '';

      bootstrapScript = self.lib.bootstrap (lib.concatMap (c: c.applications) compartments);
    };
}
