/**
 * Produce OTU heatmaps using QIIME
 *
 * Creates HTML heatmaps based on the OTU table
 */
class AutoQIIME.Analyses.Heatmap : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "heatmap";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 5);
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {

		output.add_target("heatmap/otu_table.html");
		output.add_rule("heatmap/otu_table.html: otu_table.txt mapping.txt\n\t@echo Creating OTU heatmap...\n\t$(V)test ! -d heatmap || rm -rf heatmap\n\t$(V)$(QIIME_PREFIX)make_otu_heatmap_html.py -i otu_table.txt -o heatmap/\n\n");
		return true;
	}
}
