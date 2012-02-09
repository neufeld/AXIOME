/**
 * Decorate the OTU table with the representative sequences
 */
class AutoQIIME.Analyses.TableWithSeqs : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "withseqs";
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
		output.add_target("otu_table_with_sequences.txt");
		return true;
	}
}
