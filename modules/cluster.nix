{ self, lib, ... }:
{
  options.flake.lib = lib.mkOption { type = lib.types.lazyAttrsOf lib.types.raw; };

  config.flake.lib = {
    mkCluster =
      name: clusterConfig:
      let
        resolve = component: if lib.isFunction component then component args else component;
        meta = clusterConfig.meta or { };
        args = { inherit meta; };

        resolveRules =
          value:
          value
          // lib.genAttrs [ "defaults" "generators" "overrides" ] (
            field: map resolve (value.${field} or [ ])
          );

        resolveCompartment =
          compartment:
          let
            resolved = resolveRules (resolve compartment);
          in
          resolved // { modules = map resolve (resolved.modules or [ ]); };

        resolvedConfig = resolveRules clusterConfig // {
          compartments = map resolveCompartment (clusterConfig.compartments or [ ]);
          modules = map resolve (clusterConfig.modules or [ ]);
          inherit meta name;
        };

        cluster = self.lib.validation.cluster (
          (lib.evalModules {
            modules = [
              {
                options.cluster = lib.mkOption { type = self.lib.types.cluster; };
                config.cluster = resolvedConfig;
              }
            ];
          }).config.cluster
        );
      in
      cluster // { buildScript = self.lib.renderCluster cluster; };

    mkArtifacts =
      {
        cluster,
        pkgs,
        name,
      }:
      rec {
        rawArtifact = pkgs.runCommand "${name}-raw-artifact" { } ''
          bash ${cluster.buildScript} "$out"
        '';

        artifact = pkgs.runCommand "${name}-artifact" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
          shopt -s globstar
          cp -R --no-preserve=mode,ownership ${rawArtifact} "$out"
          for file in "$out"/**/*.yaml; do yq -o yaml -P -i '.' "$file"; done
        '';
      };
  };
}
