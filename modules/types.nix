{ lib, ... }:
let
  jsonObject = lib.types.attrsOf lib.types.json;
  dynamic = type: lib.types.addCheck lib.types.raw (value: lib.isFunction value || type.check value);

  list =
    type:
    lib.mkOption {
      type = lib.types.listOf type;
      default = [ ];
    };

  named =
    options:
    lib.types.submodule {
      options = options // {
        name = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
        };
      };
    };

  matcher =
    field: type:
    lib.types.submodule (
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
          match = lib.mkOption { type = dynamic jsonObject; };
          ${field} = lib.mkOption { inherit type; };
        };
      }
    );

  ruleOptions = {
    defaults = list types.rule;
    overrides = list types.rule;
    generators = list types.generator;
  };

  compartmentOptions = ruleOptions // {
    priority = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };
    modules = list types.module;
  };

  types = rec {
    inherit jsonObject;

    rule = matcher "apply" (dynamic jsonObject);
    generator = matcher "generate" (dynamic (lib.types.listOf jsonObject));

    module = named {
      modules = lib.mkOption { type = lib.types.listOf jsonObject; };
    };

    compartmentConfig = lib.types.submodule { options = compartmentOptions; };
    compartment = named compartmentOptions;

    cluster = lib.types.submodule {
      options = ruleOptions // {
        options = lib.mkOption {
          type = jsonObject;
          default = { };
        };
        compartments = list compartment;
      };
    };
  };
in
{
  flake.lib.types = types;
}
