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
      opt =
        type:
        lib.mkOption {
          type = lib.types.attrsOf lib.types.deferredModule;
          default = { };

          apply = lib.mapAttrs (
            name: value:
            { meta, ... }:
            (lib.evalModules {
              specialArgs = { inherit meta; };
              modules = [
                { options = removeAttrs (type.getSubOptions [ name ]) [ "_module" ]; }
                value
                { config.name = name; }
              ];
            }).config
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
          bootstrap = lib.mapAttrs (_: output: output.bootstrap) artifactsBySystem;
          artifacts = lib.mapAttrs (_: output: output.artifact) artifactsBySystem;
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
        clusterCompartments = opt self.lib.types.compartment;
        clusterApplications = opt self.lib.types.application;
        clusterOverrides = opt self.lib.types.rule;
        clusterDefaults = opt self.lib.types.rule;

        clusters = lib.mkOption {
          apply = clusters: lib.mapAttrs (name: _: addArtifacts name (resolveCluster clusters name)) clusters;
          type = lib.types.attrsOf lib.types.raw;
          default = { };
        };
      };
    };
}
