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
          ruleChecks = rules: [
            (unique "override" rules.overrides)
            (unique "default" rules.defaults)
          ];

          applications = lib.concatMap (c: c.applications) v.compartments;
          embeddedApplications = lib.concatMap (
            application:
            lib.concatMap (
              resource:
              lib.optional (resource.kind or null == "Application" && resource.metadata.name or null != null) {
                name = resource.metadata.name;
              }
            ) application.resources
          ) applications;

          checks =
            ruleChecks v
            ++ lib.concatMap (
              c:
              ruleChecks {
                overrides = v.overrides ++ c.overrides;
                defaults = v.defaults ++ c.defaults;
              }
            ) v.compartments
            ++ [
              (unique "application" (applications ++ embeddedApplications))
              (unique "compartment" v.compartments)
            ];
        in
        assert lib.all lib.id checks;
        v;
    in
    {
      inherit cluster unique;
    };
}
