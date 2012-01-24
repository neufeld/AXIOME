/**
 * Make a rank-abundance curve using QIIME
 */
class AutoQIIME.Analyses.RankAbundance : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "rankabundance";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		output.add_target("rank_abundance/rank_abundance.pdf");
		return true;
	}
}
