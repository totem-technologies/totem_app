/// Link to a node in the Totem Figma file, for a story's `designLink`.
///
/// [node] is the id as Figma shows it, e.g. `3734:10292`.
String figma(String node) =>
    'https://www.figma.com/design/nzPywoKAu4SibX3T9PLNx3/Totem'
    '?node-id=${node.replaceAll(':', '-')}';
