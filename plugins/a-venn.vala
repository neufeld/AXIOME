/**
 * Produce venn diagram plots using R and Vennerable
 *
 * Creates Venn diagrams of the metadata clusters using the OTU table and mapping file
 */
class AXIOME.Analyses.Venn : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "venn";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 6);
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		output.add_target("venn/abundance_venn.pdf");
		if ( is_version_at_least(1,5) || output.pipeline.to_string() == "mothur" ) {
			output.add_rule("venn/abundance_venn.pdf: otu_table.txt mapping.txt\n\t@echo Creating Venn diagram plots...\n\t$(V)test -d venn || mkdir venn\n\taq-venn -i otu_table.tab -o venn/abundance_venn.pdf -m mapping.txt\n\n");
		} else {
			output.add_rule("venn/abundance_venn.pdf: otu_table.tab mapping.txt\n\t@echo Creating Venn diagram plots...\n\t$(V)test -d venn || mkdir venn\n\taq-venn -i otu_table.txt -o venn/abundance_venn.pdf -m mapping.txt\n\n");
		}
		return true;
	}
}
