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
          checks =
            lib.concatMap (c: [
              (unique "generator" (v.generators ++ c.generators))
              (unique "override" (v.overrides ++ c.overrides))
              (unique "default" (v.defaults ++ c.defaults))
            ]) v.compartments
            ++ [
              (unique "cluster file" ([ { name = "cluster-${v.name}"; } ] ++ v.modules))
              (unique "module" (v.modules ++ lib.concatMap (c: c.modules) v.compartments))
              (unique "compartment" v.compartments)
              (unique "generator" v.generators)
              (unique "override" v.overrides)
              (unique "default" v.defaults)
            ];
        in
        assert lib.all lib.id checks;
        v;
    in
    {
      inherit cluster unique;
    };
}
