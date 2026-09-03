{ lib, ... }:
let
  dynamic = type: lib.types.either (lib.types.functionTo lib.types.raw) type;
  jsonObject = lib.types.attrsOf lib.types.json;

  listOption =
    type:
    lib.mkOption {
      type = lib.types.listOf type;
      default = [ ];
    };

  emptyJsonOption = lib.mkOption {
    type = jsonObject;
    default = { };
  };

  submodule = options: lib.types.submodule { inherit options; };

  namedSubmodule =
    options:
    submodule (
      options
      // {
        name = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
        };
      }
    );

  ruleOptions = {
    overrides = listOption types.rule;
    defaults = listOption types.rule;
  };

  metaOptions = {
    image = lib.mkOption { type = lib.types.str; };
    tag = lib.mkOption { type = lib.types.str; };
  };

  namespaceOptions = {
    name = lib.mkOption { type = lib.types.str; };
    annotations = emptyJsonOption;
    labels = emptyJsonOption;
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
      type = submodule namespaceOptions;
    };
    bootstrap = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    source = lib.mkOption {
      type = lib.types.nullOr jsonObject;
      default = null;
    };
    sources = listOption jsonObject;
    metadata = emptyJsonOption;
    spec = emptyJsonOption;
  };

  compartmentOptions = ruleOptions // {
    applications = listOption types.application;
    meta = emptyJsonOption;
    priority = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };
  };

  types = rec {
    applicationConfig = submodule applicationOptions;
    compartmentConfig = submodule compartmentOptions;
    application = namedSubmodule applicationOptions;
    rule = lib.types.submodule (
      { name, ... }:
      {
        options = {
          match = lib.mkOption { type = dynamic jsonObject; };
          apply = lib.mkOption { type = dynamic jsonObject; };
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
    compartment = namedSubmodule compartmentOptions;
    inherit dynamic jsonObject;

    cluster = submodule (
      ruleOptions
      // {
        compartments = listOption compartment;

        meta = lib.mkOption {
          type = submodule metaOptions;
        };

        name = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
        };
      }
    );
  };
in
{
  options.flake.lib = lib.mkOption { type = lib.types.lazyAttrsOf lib.types.raw; };
  config.flake.lib.types = types;
}
