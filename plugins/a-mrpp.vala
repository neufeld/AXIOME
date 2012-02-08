/**
 * Compute Multi Response Permutation Procedure of within- versus among-group dissimilarities in R
 */
class AutoQIIME.Analyses.MRPPGraphs : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "mrpp";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		output.add_target("mrpp.pdf");
		return true;
	}
}
