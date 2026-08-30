{ lib, ... }:
let
  listOf =
    type:
    lib.mkOption {
      type = lib.types.listOf type;
      default = [ ];
    };

  jsonObject = lib.types.attrsOf lib.types.json;
  dynamicJson = lib.types.addCheck lib.types.raw (
    value: lib.isFunction value || jsonObject.check value
  );

  nameOption = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
  };

  rules = listOf types.rule;

  types = rec {
    inherit jsonObject;

    rule = lib.types.submodule (
      { name, ... }:
      {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = name;
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };
          match = lib.mkOption { type = dynamicJson; };
          apply = lib.mkOption { type = dynamicJson; };
        };
      }
    );

    module = lib.types.submodule {
      options = {
        name = nameOption;
        modules = lib.mkOption {
          type = lib.types.listOf jsonObject;
        };
      };
    };

    compartmentConfig = lib.types.submodule {
      options = compartmentOptions;
    };

    compartment = lib.types.submodule {
      options = compartmentOptions // {
        name = nameOption;
      };
    };

    cluster = lib.types.submodule {
      options = {
        defaults = rules;
        overrides = rules;
        compartments = listOf compartment;
      };
    };
  };

  compartmentOptions = {
    defaults = rules;
    overrides = rules;
    dependsOn = listOf lib.types.str;
    modules = listOf types.module;
    healthChecks = listOf types.jsonObject;
  };
in
{
  flake.lib.types = types;
}
