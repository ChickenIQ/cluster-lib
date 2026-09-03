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
      namedAttrsOption =
        type:
        lib.mkOption {
          type = lib.types.attrsOf (self.lib.types.dynamic type);
          default = { };

          apply = lib.mapAttrs (
            name: value:
            if lib.isFunction value then args: value args // { inherit name; } else value // { inherit name; }
          );
        };

      addArtifacts =
        name: clusterConfig:
        let
          cluster = self.lib.mkCluster name clusterConfig;
          artifactsBySystem = lib.genAttrs config.systems (
            system:
            withSystem system (
              { pkgs, ... }:
              self.lib.mkArtifacts { inherit cluster name pkgs; }
            )
          );
        in
        cluster
        // {
          artifacts = lib.mapAttrs (_: output: output.artifact) artifactsBySystem;
          bootstrap = lib.mapAttrs (_: output: output.bootstrap) artifactsBySystem;
          rawArtifacts = lib.mapAttrs (_: output: output.rawArtifact) artifactsBySystem;
        };

      resolveCluster =
        clusters: name:
        let
          bases = map (resolveCluster clusters) (cluster.extends or [ ]);
          cluster = clusters.${name};
        in
        lib.foldl' lib.recursiveUpdate { } (bases ++ [ (removeAttrs cluster [ "extends" ]) ]);
    in
    {
      options.flake = {
        clusterCompartments = namedAttrsOption self.lib.types.compartmentConfig;
        clusterApplications = namedAttrsOption self.lib.types.applicationConfig;
        clusterOverrides = namedAttrsOption self.lib.types.rule;
        clusterDefaults = namedAttrsOption self.lib.types.rule;

        clusters = lib.mkOption {
          apply = clusters: lib.mapAttrs (name: _: addArtifacts name (resolveCluster clusters name)) clusters;
          type = lib.types.attrsOf lib.types.raw;
          default = { };
        };
      };
    };
}
