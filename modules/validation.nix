{ lib, ... }:
{
  flake.lib.validation =
    let
      unique =
        kind: values:
        let
          names = map (value: value.name) values;
        in
        lib.assertMsg (lib.allUnique names) "${kind} names must be unique: ${lib.concatStringsSep ", " names}";

      cluster =
        v:
        let
          modules = v.modules ++ lib.concatMap (c: c.modules) v.compartments;
          applications = lib.concatMap (
            module:
            map (application: { name = application.metadata.name; }) (
              builtins.filter (
                resource: resource.kind or null == "Application" && resource.metadata.name or null != null
              ) module.modules
            )
          ) modules;

          checks =
            lib.concatMap (c: [
              (unique "generator" (v.generators ++ c.generators))
              (unique "override" (v.overrides ++ c.overrides))
              (unique "default" (v.defaults ++ c.defaults))
            ]) v.compartments
            ++ [
              (unique "cluster file" ([ { name = "cluster-${v.name}"; } ] ++ v.modules))
              (unique "application" (modules ++ applications))
              (unique "compartment" v.compartments)
              (unique "generator" v.generators)
              (unique "override" v.overrides)
              (unique "default" v.defaults)
              (unique "module" modules)
            ];
        in
        assert lib.all lib.id checks;
        v;
    in
    {
      inherit cluster unique;
    };
}
