{ self, ... }:
{
  flake.flakeModules.default =
    {
      withSystem,
      config,
      lib,
      ...
    }:
    let
      addOutputs =
        name: clusterConfig:
        let
          cluster = self.lib.mkCluster clusterConfig;

          outputs = lib.genAttrs config.systems (
            system:
            withSystem system (
              { pkgs, ... }:
              self.lib.mkArtifacts { inherit cluster name pkgs; }
            )
          );

          artifacts = lib.mapAttrs (_: output: output.artifact) outputs;
          rawArtifacts = lib.mapAttrs (_: output: output.rawArtifact) outputs;
        in
        cluster // { inherit artifacts rawArtifacts; };
    in
    {
      options.flake = {
        clusterModules = lib.mkOption {
          apply = lib.mapAttrs (name: manifests: { inherit name manifests; });
          type = lib.types.attrsOf (lib.types.listOf self.lib.types.manifest);
          default = { };
        };

        clusters = lib.mkOption {
          type = lib.types.attrsOf self.lib.types.cluster;
          apply = lib.mapAttrs addOutputs;
          default = { };
        };
      };
    };
}
