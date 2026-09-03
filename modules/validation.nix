{ lib, ... }:
{
  flake.lib.validation =
    let
      unique =
        kind: values:
        let
          names = map (value: value.name) values;
          duplicates = builtins.filter (n: 1 < lib.count (c: c == n) names) (lib.unique names);
        in
        lib.assertMsg (
          duplicates == [ ]
        ) "${kind} names must be unique: ${lib.concatStringsSep ", " duplicates}";

      cluster =
        v:
        let
          applications = lib.concatMap (c: c.applications) v.compartments;
          embeddedApplications = lib.concatMap (
            application:
            map (resource: { name = resource.metadata.name; }) (
              builtins.filter (
                resource: resource.kind or null == "Application" && resource.metadata.name or null != null
              ) application.resources
            )
          ) applications;

          checks =
            lib.concatMap (c: [
              (unique "generator" (v.generators ++ c.generators))
              (unique "override" (v.overrides ++ c.overrides))
              (unique "default" (v.defaults ++ c.defaults))
            ]) v.compartments
            ++ [
              (unique "application" (applications ++ embeddedApplications))
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
