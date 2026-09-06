{ self, lib, ... }:
{
  flake.lib.render =
    cluster:
    let
      applications = flatten (lib.concatMap (compartment: compartment.applications) compartments);
      bootstrap = self.lib.bootstrap applications;

      flatten =
        applications:
        lib.concatMap (application: [ application ] ++ flatten application.applications) applications;

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

      namespaces = lib.filter (namespace: namespace != null) (
        map (application: application.namespace) applications
      );

      mkYamlFile =
        doc: dst:
        let
          src = builtins.toFile (baseNameOf dst) (lib.concatMapStringsSep "\n---\n" builtins.toJSON doc);
        in
        ''install -m 0644 ${src} "$out/${dst}"'';

      renderApp = app: ''
        ${lib.optionalString (app.source != null) (
          mkYamlFile (app.resources ++ map (child: child.manifest) app.applications) app.resourcePath
        )}
        ${lib.concatMapStringsSep "\n" renderApp app.applications}
      '';

      renderCompartment = compartment: ''
        mkdir -p "$out/compartments/${compartment.name}"
        ${lib.concatMapStringsSep "\n" (
          app: mkYamlFile [ app.manifest ] app.manifestPath
        ) compartment.applications}
        ${lib.concatMapStringsSep "\n" renderApp compartment.applications}
      '';
    in
    builtins.toFile "build.sh" ''
      #!/bin/sh
      set -euo pipefail

      out="''${1:?Output dir not specified}"
      mkdir -p "$out/applications" "$out/compartments"
      install -m 0755 ${bootstrap} "$out/bootstrap.sh"
      ${lib.optionalString (namespaces != [ ]) (mkYamlFile namespaces "applications/_namespaces.yaml")}
      ${lib.concatMapStringsSep "\n" renderCompartment compartments}
    '';
}
