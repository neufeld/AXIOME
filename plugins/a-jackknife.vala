/**
 * Produce taxa plots using QIIME
 *
 * Creates bar plots and area charts using the OTU table
 */
class AutoQIIME.Analyses.JackKnife : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "jackknife";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 5);
	}
	public override bool is_only_once() {
		return false;
	}
	public override bool process(Xml.Node *definition, Output output) {

		var size = definition->get_prop("size");
		if (size == null) {
			size = "100";
		} else {
			int v = int.parse(size);
			if (v < 1) {
				definition_error(definition, "Cannot subsample to a size of \"%s\". Use a positive number.\n", size);
				return false;
			}
		}

		output.add_target("jackknife-%s/weighted_unifrac_otu_table.txt".printf(size));
		output.add_target("jackknife-%s/unweighted_unifrac_otu_table.txt".printf(size));
		output.add_rule("jackknife-%s/weighted_unifrac_otu_table.txt jackknife-%s/unweighted_unifrac_otu_table.txt: otu_table.txt mapping.txt seq.fasta_rep_set_aligned_pfiltered.tre\n\t@echo Creating 2D/3D jackknife plots at subsample size %s...\n\t$(V)test ! -d jackknife-%s || rm -rf jackknife-%s\n\t$(V)$(QIIME_PREFIX)jackknifed_beta_diversity.py -i otu_table.txt -o jackknife-%s -m mapping.txt -t seq.fasta_rep_set_aligned_pfiltered.tre -e %s\n\n".printf(size, size, size, size, size, size, size));
		return true;
	}
}
