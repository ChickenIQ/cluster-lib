{ lib, ... }:
{
  flake.lib.rules =
    let
      matching = value: builtins.filter (rule: matches rule value);
      sortRules = lib.sort (a: b: a.priority < b.priority);

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
          updated = lib.recursiveUpdate (merge (sortRules rules.defaults) value) value;
        in
        lib.recursiveUpdate updated (merge (sortRules rules.overrides) updated);
    in
    {
      evaluate =
        rules: value:
        let
          updated = apply rules value;
          generated = lib.concatMap (generator: resolve "generate" generator updated) (
            matching updated (sortRules rules.generators)
          );
        in
        [ updated ] ++ map (apply rules) generated;
    };
}
