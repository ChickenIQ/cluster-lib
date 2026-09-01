{ lib, ... }:
{
  flake.lib.mkApplicationSet =
    { compartments, options }:
    lib.recursiveUpdate {
      apiVersion = "argoproj.io/v1alpha1";
      kind = "ApplicationSet";
      metadata = {
        name = "cluster";
        namespace = "argocd";
      };
      spec = {
        goTemplateOptions = [ "missingkey=error" ];
        goTemplate = true;

        generators = [
          {
            list.elements = lib.concatMap (
              compartment:
              map (module: {
                name = "${compartment.name}-${module.name}";
                compartment = compartment.name;
                module = module.name;
              }) compartment.modules
            ) compartments;
          }
        ];

        strategy = {
          type = "RollingSync";
          rollingSync.steps = map (priority: {
            matchExpressions = [
              {
                key = "compartment";
                operator = "In";
                values = map (c: c.name) (builtins.filter (c: c.priority == priority) compartments);
              }
            ];
          }) (lib.sort builtins.lessThan (lib.unique (map (c: c.priority) compartments)));
        };

        template = {
          metadata = {
            name = "{{.name}}";
            labels."compartment" = "{{.compartment}}";
          };

          spec = {
            destination.server = "https://kubernetes.default.svc";
            project = "default";

            source = {
              path = "compartments/{{.compartment}}";
              directory.include = "{{.module}}.yaml";
              targetRevision = "latest";
            };
          };
        };
      };
    } options;
}
