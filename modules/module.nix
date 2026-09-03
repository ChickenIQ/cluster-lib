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
        type: wrap:
        lib.mkOption {
          type = lib.types.attrsOf (self.lib.types.dynamic type);
          default = { };

          apply = lib.mapAttrs (
            name: value:
            if lib.isFunction value then
              args: wrap (value args) // { inherit name; }
            else
              wrap value // { inherit name; }
          );
        };

      addPkgs =
        name: clusterConfig:
        let
          rawArtifacts = lib.mapAttrs (_: output: output.rawArtifact) pkgs;
          artifacts = lib.mapAttrs (_: output: output.artifact) pkgs;
          cluster = self.lib.mkCluster name clusterConfig;

          pkgs = lib.genAttrs config.systems (
            system:
            withSystem system (
              { pkgs, ... }:
              self.lib.mkArtifacts { inherit cluster name pkgs; }
            )
          );
        in
        cluster // { inherit artifacts rawArtifacts; };

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
        clusterCompartments = named self.lib.types.compartmentConfig lib.id;
        clusterApplications = named self.lib.types.applicationConfig lib.id;
        clusterGenerators = named self.lib.types.generator lib.id;
        clusterOverrides = named self.lib.types.rule lib.id;
        clusterDefaults = named self.lib.types.rule lib.id;

        clusters = lib.mkOption {
          apply = clusters: lib.mapAttrs (name: _: addPkgs name (resolveCluster clusters name)) clusters;
          type = lib.types.attrsOf lib.types.raw;
          default = { };
        };
      };
    };
}
