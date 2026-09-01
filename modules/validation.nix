{ lib, ... }:
{
  flake.lib.validation =
    let
      uniqueNames =
        kind: values:
        let
          names = map (value: value.name) values;
        in
        lib.assertMsg (lib.allUnique names) "${kind} names must be unique: ${lib.concatStringsSep ", " names}";

      cluster =
        value:
        let
          applications = lib.concatMap (
            compartment: map (module: { name = "${compartment.name}-${module.name}"; }) compartment.modules
          ) value.compartments;

          compartmentChecks = lib.concatMap (compartment: [
            (uniqueNames "generator" (value.generators ++ compartment.generators))
            (uniqueNames "override" (value.overrides ++ compartment.overrides))
            (uniqueNames "default" (value.defaults ++ compartment.defaults))
            (uniqueNames "module" compartment.modules)
          ]) value.compartments;

          checks = [
            (uniqueNames "compartment" value.compartments)
            (uniqueNames "generator" value.generators)
            (uniqueNames "application" applications)
            (uniqueNames "override" value.overrides)
            (uniqueNames "default" value.defaults)
          ]
          ++ compartmentChecks;
        in
        assert lib.all lib.id checks;
        value;
    in
    {
      inherit cluster uniqueNames;
    };
}
