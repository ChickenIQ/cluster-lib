{ self, lib, ... }:
{
  flake.lib.mkCluster =
    name: clusterConfig:
    let
      rawMeta = clusterConfig.meta or { };
      meta = rawMeta // {
        tag = rawMeta.tag or name;
      };

      resolve =
        meta: component: if lib.isFunction component then component { inherit meta; } else component;

      resolveRules =
        meta: value:
        value
        // {
          defaults = map (resolve meta) (value.defaults or [ ]);
          overrides = map (resolve meta) (value.overrides or [ ]);
        };

      resolveCompartment =
        compartment:
        let
          config = resolve meta compartment;
          compartmentMeta = meta // (config.meta or { });
          resolved = resolveRules compartmentMeta config;
        in
        resolved
        // {
          applications = map (resolve compartmentMeta) (resolved.applications or [ ]);
          meta = compartmentMeta;
        };

      resolvedConfig = resolveRules meta clusterConfig // {
        compartments = map resolveCompartment (clusterConfig.compartments or [ ]);
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
}
