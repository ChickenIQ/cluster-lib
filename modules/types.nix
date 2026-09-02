{ lib, ... }:
let
  dynamic = type: lib.types.either (lib.types.functionTo lib.types.raw) type;
  jsonObject = lib.types.attrsOf lib.types.json;

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
          match = lib.mkOption { type = dynamic jsonObject; };
          ${field} = lib.mkOption { inherit type; };

          priority = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };

          name = lib.mkOption {
            type = lib.types.str;
            default = name;
          };
        };
      }
    );

  ruleOptions = {
    generators = list types.generator;
    overrides = list types.rule;
    defaults = list types.rule;
  };

  compartmentOptions = ruleOptions // {
    modules = list types.module;
    priority = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };
  };

  types = rec {
    module = named { modules = lib.mkOption { type = lib.types.listOf jsonObject; }; };
    compartmentConfig = lib.types.submodule { options = compartmentOptions; };
    generator = matcher "generate" (dynamic (lib.types.listOf jsonObject));
    rule = matcher "apply" (dynamic jsonObject);
    compartment = named compartmentOptions;
    inherit dynamic jsonObject;

    cluster = lib.types.submodule {
      options = ruleOptions // {
        compartments = list compartment;

        meta = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
          default = { };
        };

        modules = list types.module;

        options = lib.mkOption {
          type = jsonObject;
          default = { };
        };

        name = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
        };
      };
    };
  };
in
{
  flake.lib.types = types;
}
