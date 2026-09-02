{ lib, ... }:
{
  flake.lib.rules =
    let
      matching = value: builtins.filter (rule: matches rule value);
      sortRules = lib.sortOn (rule: rule.priority);

      resolve =
        field: rule: value:
        if lib.isFunction rule.${field} then rule.${field} value else rule.${field};

      matches =
        rule: value:
        let
          match = resolve "match" rule value;
        in
        if builtins.isBool match then match else lib.matchAttrs match value;

      apply =
        rules: value:
        let
          merge =
            candidates: current:
            lib.foldl' (acc: rule: lib.recursiveUpdate acc (resolve "apply" rule current)) { } (
              matching current candidates
            );
          updated = lib.recursiveUpdate (merge rules.defaults value) value;
        in
        lib.recursiveUpdate updated (merge rules.overrides updated);
    in
    {
      evaluate =
        rules: value:
        let
          generated = lib.concatMap (generator: resolve "generate" generator updated) (
            matching updated sortedRules.generators
          );

          sortedRules = {
            generators = sortRules rules.generators;
            overrides = sortRules rules.overrides;
            defaults = sortRules rules.defaults;
          };

          updated = apply sortedRules value;
        in
        [ updated ] ++ map (apply sortedRules) generated;
    };
}
