/**
 * Produce NMF concordance plot
 */
class AutoQIIME.Analyses.ConcordancePlot : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "nmf-concordance";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 3);
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		output.add_target("nmf-concordance.pdf");
		return true;
	}
}

/**
 * Non-negative matrix factorization
 *
 * Do a non-negative matrix factorization at a particular degree. This relies on an R script to do the heavy lifting.
 */
class AutoQIIME.Analyses.NonnegativeMatrixFactorization : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "nmf";
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
		var degree = int.parse(definition-> get_prop("degree"));
		if (degree < 2 || degree > output.known_samples.size - 1) {
			definition_error(definition, "The degree \"%s\" is not resonable for NMF.\n", definition-> get_prop("degree"));
			return false;
		}
		output.add_target("nmf_%d.pdf".printf(degree));
		output.add_rulef("nmf_%d.pdf: otu_table.txt mapping.extra\n\t@echo Computing NMF for degree %d...\n\t$(V)aq-nmf %d\n\n", degree, degree, degree);
		return true;
	}
}
