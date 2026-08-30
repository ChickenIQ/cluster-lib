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
      namedObjects = lib.mkOption {
        apply = lib.mapAttrs (name: value: value // { inherit name; });
        type = lib.types.attrsOf self.lib.types.jsonObject;
        default = { };
      };

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
        clusterModules = namedObjects;
        clusterDefaults = namedObjects;
        clusterOverrides = namedObjects;
        clusterCompartments = namedObjects;

        clusters = lib.mkOption {
          type = lib.types.attrsOf self.lib.types.cluster;
          apply = lib.mapAttrs addOutputs;
          default = { };
        };
      };
    };
}
