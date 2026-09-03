{ lib, ... }:
let
  apply = "kubectl apply --server-side --force-conflicts -f";

  render =
    compartment: application:
    lib.optionalString application.bootstrap ''
      ${lib.concatMapStringsSep "\n"
        (
          source:
          "helm template ${
            lib.escapeShellArgs [
              application.name
              source.chart
              "--repo"
              source.repoURL
              "--version"
              source.targetRevision
              "--namespace"
              application.namespace.name
              "--include-crds"
            ]
          } | ${apply} -"
        )
        (
          builtins.filter (source: source ? chart) (
            lib.optional (application.source != null) application.source ++ application.sources
          )
        )
      }
      ${apply} ${lib.escapeShellArg "compartments/${compartment.name}/${application.name}.yaml"}
    '';
in
{
  flake.lib = {
    renderBootstrap =
      cluster:
      builtins.toFile "bootstrap.sh" ''
        #!/bin/sh
        set -eu

        cd "$(dirname "$0")"
        ${lib.concatMapStringsSep "\n" (
          compartment: lib.concatMapStringsSep "\n" (render compartment) compartment.applications
        ) cluster.compartments}
      '';

    mkArtifacts =
      {
        cluster,
        pkgs,
        name,
      }:
      rec {
        rawArtifact = pkgs.runCommand "${name}-raw-artifact" { } ''
          bash ${cluster.buildScript} "$out"
          cp ${cluster.bootstrapScript} "$out/bootstrap.sh"
          chmod +x "$out/bootstrap.sh"
        '';

        artifact = pkgs.runCommand "${name}-artifact" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
          cp -R --no-preserve=mode,ownership ${rawArtifact} "$out"
          chmod +x "$out/bootstrap.sh"
          shopt -s globstar

          for file in "$out"/**/*.yaml; do yq -o yaml -P -i '.' "$file"; done
        '';

        bootstrap = pkgs.writeShellScriptBin "bootstrap" ''
          exec ${artifact}/bootstrap.sh "$@"
        '';
      };
  };
}
