{ self, lib, ... }:
let
  apply = "kubectl apply --server-side --force-conflicts";

  renderHelm =
    manifest: source:
    let
      cmd = if values == null then template else "printf %s ${lib.escapeShellArg values} | ${template}";
      values = if helm ? valuesObject then builtins.toJSON helm.valuesObject else helm.values or null;
      template = "helm template ${lib.escapeShellArgs args}";
      helm = source.helm or { };
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
    in
    "${cmd} | ${apply} --namespace ${lib.escapeShellArg manifest.spec.destination.namespace} -f -";

  renderApp =
    rawApp:
    let
      helmSources = builtins.filter (source: !isLocal source) sources;
      app = self.lib.validation.bootstrap rawApp;
      isLocal = source: source == app.source;
      sources = manifest.spec.sources;
      inherit (app) manifest;
    in
    lib.optionalString app.bootstrap ''
      printf '%s\n' ${lib.escapeShellArg (builtins.toJSON app.namespace)} | ${apply} -f -
      ${lib.concatMapStringsSep "\n" (renderHelm manifest) helmSources}
      ${apply} --namespace ${lib.escapeShellArg manifest.spec.destination.namespace} -f ${lib.escapeShellArg app.resourcePath}
    '';
in
{
  flake.lib.bootstrap =
    apps:
    builtins.toFile "bootstrap.sh" ''
      #!/bin/sh
      set -euo pipefail

      cd "$(dirname "$0")"
      ${lib.concatMapStringsSep "\n" renderApp apps}
    '';
}
