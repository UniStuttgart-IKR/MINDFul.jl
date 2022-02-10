export edgeify

"Converts a node path to a sequence of edges"
edgeify(p) = map(Edge , zip(p, p[2:end]));
