{ lib, ... }:
let
  listOf =
    type:
    lib.mkOption {
      type = lib.types.listOf type;
      default = [ ];
    };

  jsonObject = lib.types.attrsOf lib.types.json;
  dynamic = type: lib.types.addCheck lib.types.raw (value: lib.isFunction value || type.check value);
  dynamicJson = dynamic jsonObject;
  dynamicJsonObjects = dynamic (lib.types.listOf jsonObject);

  matcherOptions = name: {
    name = lib.mkOption {
      type = lib.types.str;
      default = name;
    };
    priority = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };
    match = lib.mkOption { type = dynamicJson; };
  };

  nameOption = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
  };

  rules = listOf types.rule;
  generators = listOf types.generator;

  types = rec {
    inherit jsonObject;

    rule = lib.types.submodule (
      { name, ... }:
      {
        options = matcherOptions name // {
          apply = lib.mkOption { type = dynamicJson; };
        };
      }
    );

    generator = lib.types.submodule (
      { name, ... }:
      {
        options = matcherOptions name // {
          generate = lib.mkOption { type = dynamicJsonObjects; };
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
        inherit generators;
        compartments = listOf compartment;
      };
    };
  };

  compartmentOptions = {
    defaults = rules;
    overrides = rules;
    inherit generators;
    dependsOn = listOf lib.types.str;
    modules = listOf types.module;
    healthChecks = listOf types.jsonObject;
  };
in
{
  flake.lib.types = types;
}
