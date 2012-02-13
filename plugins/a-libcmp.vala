/**
 * Compare the distribution of taxa between pairs of libraries
 *
 * This relies on an R script to do the heavy lifting. A summarized OTU table is needed.
 */
class AutoQIIME.Analyses.LibraryComparison : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "compare";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 2);
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		var taxlevel = TaxonomicLevel.parse(definition-> get_prop("level"));
		if (taxlevel == null) {
			definition_error(definition, "Unknown taxonomic level \"%s\" in library abundance comparison analysis.\n", definition-> get_prop("level"));
			return false;
		}
		var taxname = taxlevel.to_string();
		output.make_summarized_otu(taxlevel, "");
		output.add_target("correlation_%s.pdf".printf(taxname));
		output.add_rulef("correlation_%s.pdf: otu_table_summarized_%s.txt mapping.extra\n\t@echo Comparing libraries at %s-level...\n\t$(V)aq-cmplibs %s\n\n", taxname, taxname, taxname, taxname);
		return true;
	}
}
