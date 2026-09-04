{ lib, ... }:
let
  apply = "kubectl apply --server-side --force-conflicts -f";

  renderHelm =
    manifest: source:
    let
      helm = source.helm or { };
      values = if helm ? valuesObject then builtins.toJSON helm.valuesObject else helm.values or null;
      args = [
        (helm.releaseName or manifest.metadata.name)
        source.chart
        "--repo"
        source.repoURL
        "--version"
        source.targetRevision
        "--namespace"
        manifest.spec.destination.namespace
      ]
      ++ lib.optional (!(helm.skipCrds or false)) "--include-crds"
      ++ lib.optionals (values != null) [
        "--values"
        "-"
      ];

      template = "helm template ${lib.escapeShellArgs args}";
      cmd = if values == null then template else "printf %s ${lib.escapeShellArg values} | ${template}";
    in
    assert lib.assertMsg (
      (helm.valueFiles or [ ]) == [ ]
      && (helm.parameters or [ ]) == [ ]
      && (helm.fileParameters or [ ]) == [ ]
    ) "bootstrap only supports inline Helm values via values or valuesObject";
    ''
      template=$(${cmd})
      printf '%s\n' "$template" | ${apply} -
    '';

  renderApp =
    app:
    let
      inherit (app) manifest;
      sources = manifest.spec.sources;
      isLocal = source: source == app.source;
      renderSource =
        source:
        if isLocal source then
          apply + " " + lib.escapeShellArg app.resourcePath
        else
          renderHelm manifest source;
    in
    lib.optionalString app.bootstrap (
      assert lib.assertMsg (
        lib.count isLocal sources == 1
      ) "bootstrap requires exactly one generated resource source";

      assert lib.assertMsg (lib.all (
        source: isLocal source || source ? chart
      ) sources) "bootstrap only supports the generated resource source and Helm sources";

      ''
        printf '%s\n' ${lib.escapeShellArg (builtins.toJSON app.namespace)} | ${apply} -
        ${lib.concatMapStringsSep "\n" renderSource sources}
      ''
    );
in
{
  flake.lib.bootstrap =
    apps:
    builtins.toFile "bootstrap.sh" ''
      #!/bin/sh
      set -eu

      cd "$(dirname "$0")"
      ${lib.concatMapStringsSep "\n" renderApp apps}
    '';
}
