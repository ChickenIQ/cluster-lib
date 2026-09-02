{ lib, ... }:
{
  flake.lib.mkApplicationSet =
    {
      compartments,
      options,
      name,
    }:
    lib.recursiveUpdate {
      apiVersion = "argoproj.io/v1alpha1";
      kind = "ApplicationSet";
      metadata = {
        name = "cluster-${name}";
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
            name = "{{.module}}";
            labels."compartment" = "{{.compartment}}";
          };

          spec = {
            destination.server = "https://kubernetes.default.svc";
            syncPolicy.automated.enabled = false;
            project = "default";

            source = {
              path = "compartments/{{.compartment}}";
              directory.include = "{{.module}}.yaml";
              targetRevision = name;
            };
          };
        };
      };
    } options;
}
