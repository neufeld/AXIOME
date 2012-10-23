/**
 * Produce NMF concordance plot
 */
class AXIOME.Analyses.ConcordancePlot : RuleProcessor {
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
 * Produce NMF concordance plot, and auto calculate NMF for candidate degrees
 */
class AXIOME.Analyses.AutoNMFPlot : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "nmf-auto";
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
		output.add_target("nmf-concordance-auto.pdf");
		return true;
	}
}

/**
 * Non-negative matrix factorization
 *
 * Do a non-negative matrix factorization at a particular degree. This relies on an R script to do the heavy lifting.
 */
class AXIOME.Analyses.NonnegativeMatrixFactorization : RuleProcessor {
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
			definition_error(definition, "The degree \"%s\" is not reasonable for NMF.\n", definition-> get_prop("degree"));
			return false;
		}
		output.add_target("nmf/nmf_%d.pdf".printf(degree));
		if ( is_version_at_least(1,5) ) {
			output.add_rulef("nmf/nmf_%d.pdf: otu_table.tab mapping.extra\n\t@echo Computing NMF for degree %d...\n\t$(V)aq-nmf -B %d\n\n", degree, degree, degree);
		} else  {
			output.add_rulef("nmf/nmf_%d.pdf: otu_table.txt mapping.extra\n\t@echo Computing NMF for degree %d...\n\t$(V)aq-nmf %d\n\n", degree, degree, degree);
		}
	return true;
	}
}
