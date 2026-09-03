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

  metaOptions = {
    image = lib.mkOption { type = lib.types.str; };
    tag = lib.mkOption { type = lib.types.str; };
  };

  namespaceOptions = {
    name = lib.mkOption { type = lib.types.str; };
    annotations = lib.mkOption {
      type = jsonObject;
      default = { };
    };
    labels = lib.mkOption {
      type = jsonObject;
      default = { };
    };
    type = lib.mkOption {
      type = lib.types.enum [
        ""
        "privileged"
        "baseline"
        "restricted"
      ];
      default = "";
    };
  };

  applicationOptions = {
    resources = lib.mkOption { type = lib.types.listOf jsonObject; };
    namespace = lib.mkOption {
      type = lib.types.submodule { options = namespaceOptions; };
    };
    bootstrap = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    source = lib.mkOption {
      type = lib.types.nullOr jsonObject;
      default = null;
    };
    sources = list jsonObject;
    metadata = lib.mkOption {
      type = jsonObject;
      default = { };
    };
    spec = lib.mkOption {
      type = jsonObject;
      default = { };
    };
  };

  compartmentOptions = ruleOptions // {
    applications = list types.application;
    meta = lib.mkOption {
      type = jsonObject;
      default = { };
    };
    priority = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };
  };

  types = rec {
    applicationConfig = lib.types.submodule { options = applicationOptions; };
    application = named applicationOptions;
    compartmentConfig = lib.types.submodule { options = compartmentOptions; };
    generator = matcher "generate" (dynamic (lib.types.listOf jsonObject));
    rule = matcher "apply" (dynamic jsonObject);
    compartment = named compartmentOptions;
    inherit dynamic jsonObject;

    cluster = lib.types.submodule {
      options = ruleOptions // {
        compartments = list compartment;

        meta = lib.mkOption {
          type = lib.types.submodule { options = metaOptions; };
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
  options.flake.lib = lib.mkOption { type = lib.types.lazyAttrsOf lib.types.raw; };
  config.flake.lib.types = types;
}
