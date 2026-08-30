{ lib, ... }:
let
  nameOption = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
  };
in
{
  flake.lib.types = rec {
    jsonObject = lib.types.attrsOf lib.types.json;

    rules = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = nameOption;
            priority = lib.mkOption {
              type = lib.types.int;
              default = 0;
            };
            match = lib.mkOption { type = jsonObject; };
            apply = lib.mkOption { type = jsonObject; };
          };
        }
      );
      default = [ ];
    };

    module = lib.types.submodule {
      options = {
        name = nameOption;

        modules = lib.mkOption {
          type = lib.types.listOf jsonObject;
        };
      };
    };

    compartment = lib.types.submodule {
      options = {
        name = nameOption;

        defaults = rules;
        overrides = rules;

        dependsOn = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };

        modules = lib.mkOption {
          type = lib.types.listOf module;
          default = [ ];
        };

        healthChecks = lib.mkOption {
          type = lib.types.listOf jsonObject;
          default = [ ];
        };
      };
    };

    cluster = lib.types.submodule {
      options = {
        defaults = rules;
        overrides = rules;

        compartments = lib.mkOption {
          type = lib.types.listOf compartment;
          default = [ ];
        };
      };
    };
  };
}
