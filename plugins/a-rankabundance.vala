/**
 * Make a rank-abundance curve using QIIME
 */
class AXIOME.Analyses.RankAbundance : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "rankabundance";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 1);
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		var pipeline = output.pipeline;
		if (pipeline.to_string() == "mothur") {
			definition_error(definition, "Rank abundandance curve plugin is not available for mothur. Sorry! Skipping...\n");
		}
		else if (pipeline.to_string() == "qiime") {
			output.add_target("rank_abundance/rank_abundance.pdf");
		}
		return true;
	}
}
