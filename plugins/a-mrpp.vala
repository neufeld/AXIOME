/**
 * Compute Multi Response Permutation Procedure of within- versus among-group dissimilarities in R
 */
class AXIOME.Analyses.MRPPGraphs : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "mrpp";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 3);
	}
	public override bool is_only_once() {
		return false;
	}
	public override bool process(Xml.Node *definition, Output output) {
		var method = definition->get_prop("method");
		string[] methods = {"manhattan", "euclidean", "canberra", "bray", "kulczynski", "jaccard", "gower", "altGower", "morisita", "horn", "mountford", "raup", "binomial", "chao", "cao"};

		if ( method != null ) {
			if ( ! ( method in methods ) ) {
				definition_error(definition, "Unrecognized PCoA dissimilarity method. Choose one of: manhattan, euclidean, canberra, bray, kulczynski, jaccard, gower, altGower, morisita, horn, mountford, raup , binomial, chao, cao.\n");
				return false;
			}
		} else {
			method = "bray";
		}

		output.add_target("mrpp/mrpp-%s.pdf".printf(method));
		output.add_target("mrpp/mrpp-%s.txt".printf(method));
		if ( is_version_at_least(1,5) || output.pipeline.to_string() == "mothur" ) {
			output.add_rulef("mrpp/mrpp-%s.pdf mrpp/mrpp-%s.txt: mapping.txt otu_table.tab\n\t@echo Computing Multi Response Permutation Procedure with method '%s'\n\t$(V)aq-mrpp -i otu_table.tab -o mrpp -m mapping.txt -d %s\n\n", method, method, method, method);
		} else {
    output.add_rulef("mrpp/mrpp-%s.pdf mrpp/mrpp-%s.txt: mapping.txt otu_table.txt\n\t@echo Computing Multi Response Permutation Procedure with method '%s'\n\t$(V)aq-mrpp -i otu_table.txt -o mrpp -m mapping.txt -d %s\n\n", method, method, method, method);
		}
		return true;
	}
}
