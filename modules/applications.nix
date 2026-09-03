{ lib, ... }:
{
  flake.lib = {
    mkApplication =
      {
        application,
        meta,
        path,
        priority,
      }:
      {
        apiVersion = "argoproj.io/v1alpha1";
        kind = "Application";
        metadata = lib.recursiveUpdate {
          inherit (application) name;
          namespace = "argocd";
          annotations."argocd.argoproj.io/sync-wave" = toString priority;
        } application.metadata;

        spec = lib.recursiveUpdate {
          destination = {
            server = "https://kubernetes.default.svc";
            namespace = application.namespace.name;
          };
          project = "default";
          sources = [
            {
              repoURL = meta.image;
              targetRevision = meta.tag;
              inherit path;
              directory.include = "${application.name}.yaml";
            }
          ]
          ++ lib.optional (application.source != null) application.source
          ++ application.sources;
        } application.spec;
      };

    mkNamespace = namespace: {
      apiVersion = "v1";
      kind = "Namespace";
      metadata = {
        inherit (namespace) name annotations;
        labels =
          lib.optionalAttrs (namespace.type != "") {
            "pod-security.kubernetes.io/enforce" = namespace.type;
            "pod-security.kubernetes.io/audit" = namespace.type;
            "pod-security.kubernetes.io/warn" = namespace.type;
          }
          // namespace.labels;
      };
    };
  };
}
