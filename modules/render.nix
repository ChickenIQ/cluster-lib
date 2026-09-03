{ self, lib, ... }:
{
  flake.lib.renderCluster =
    cluster:
    let
      mkYamlFile =
        documents: destination:
        let
          src = builtins.toFile (baseNameOf destination) (
            lib.concatMapStringsSep "\n---\n" builtins.toJSON documents
          );
        in
        ''cp ${src} "$out/${destination}"'';

      renderApplication =
        evaluate: meta: priority: path: application:
        let
          manifest = evaluate (self.lib.mkApplication { inherit application meta path priority; });
          resources = map evaluate (
            [ (self.lib.mkNamespace application.namespace) ] ++ application.resources
          );
        in
        ''
          ${mkYamlFile resources "${path}/${application.name}.yaml"}
          ${mkYamlFile [ manifest ] "applications/${application.name}.yaml"}
        '';

      mkCompartment =
        compartment:
        let
          path = "compartments/${compartment.name}";
          evaluate = self.lib.rules.evaluate {
            overrides = cluster.overrides ++ compartment.overrides;
            defaults = cluster.defaults ++ compartment.defaults;
          };
        in
        ''
          mkdir -p "$out/${path}"
          ${lib.concatMapStringsSep "\n" (
            renderApplication evaluate compartment.meta compartment.priority path
          ) compartment.applications}
        '';
    in
    builtins.toFile "build.sh" ''
      #!/usr/bin/env -S bash -euo pipefail

      out="''${1:?Output dir not specified}"
      mkdir -p "$out/applications" "$out/compartments"
      ${lib.concatMapStringsSep "\n" mkCompartment cluster.compartments}
    '';
}
