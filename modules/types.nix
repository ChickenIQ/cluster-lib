{ lib, ... }:
{
  flake.lib.types = rec {
    manifest = lib.types.attrsOf lib.types.anything;

    defaults = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            match = lib.mkOption { type = manifest; };
            apply = lib.mkOption { type = manifest; };
          };
        }
      );
      default = [ ];
    };

    clusterModule = lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
        };

        manifests = lib.mkOption {
          type = lib.types.listOf manifest;
        };
      };
    };

    compartment = lib.types.submodule {
      options = {
        settings = lib.mkOption {
          type = manifest;
          default = { };
        };

        inherit defaults;

        dependsOn = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };

        clusterModules = lib.mkOption {
          type = lib.types.listOf clusterModule;
          default = [ ];
        };

        healthChecks = lib.mkOption {
          type = lib.types.listOf manifest;
          default = [ ];
        };
      };
    };

    cluster = lib.types.submodule {
      options = {
        inherit defaults settings;

        compartments = lib.mkOption {
          type = lib.types.attrsOf compartment;
          default = { };
        };
      };
    };

    settings = lib.mkOption {
      type = manifest;
      default = {
        internalNamespace = "flux-internal";
        namespace = "flux-system";
        sourceRef = {
          namespace = "flux-system";
          kind = "OCIRepository";
          name = "flux-system";
        };
        retryInterval = "10s";
        interval = "12h";
        prune = true;
        force = true;
      };
    };
  };
}
