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
      named =
        type:
        lib.mkOption {
          apply = lib.mapAttrs (name: value: value // { inherit name; });
          type = lib.types.attrsOf type;
          default = { };
        };

      addPkgs =
        name: clusterConfig:
        let
          cluster = self.lib.mkCluster clusterConfig;

          pkgs = lib.genAttrs config.systems (
            system:
            withSystem system (
              { pkgs, ... }:
              self.lib.mkArtifacts { inherit cluster name pkgs; }
            )
          );

          artifacts = lib.mapAttrs (_: output: output.artifact) pkgs;
          rawArtifacts = lib.mapAttrs (_: output: output.rawArtifact) pkgs;
        in
        cluster // { inherit artifacts rawArtifacts; };

      resolveCluster =
        clusters: name:
        let
          cluster = clusters.${name};
          bases = map (resolveCluster clusters) (cluster.extends or [ ]);
        in
        lib.foldl' lib.recursiveUpdate { } (bases ++ [ (removeAttrs cluster [ "extends" ]) ]);
    in
    {
      options.flake = {
        clusterCompartments = named self.lib.types.compartmentConfig;
        clusterGenerators = named self.lib.types.generator;
        clusterOverrides = named self.lib.types.rule;
        clusterDefaults = named self.lib.types.rule;

        clusterModules = lib.mkOption {
          apply = lib.mapAttrs (name: modules: { inherit name modules; });
          type = lib.types.attrsOf (lib.types.listOf self.lib.types.jsonObject);
          default = { };
        };

        clusters = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
          apply = clusters: lib.mapAttrs (name: _: addPkgs name (resolveCluster clusters name)) clusters;
          default = { };
        };
      };
    };
}
