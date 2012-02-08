/**
 * Compute Dufrene-Legendre indicator species analysis in R
 */
class AutoQIIME.Analyses.DuLegStats : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "duleg";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		output.add_target("duleg.txt");
		return true;
	}
}
