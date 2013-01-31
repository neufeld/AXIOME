/**
 * Produce principle component analysis using R
 *
 * Do prinicpal component analysis on the taxa and the other (numeric) variables specified.
 */
class AXIOME.Analyses.PrincipalComponentAnalysis : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "pca";
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
		if (!output.vars.has_key("Colour") || output.vars["Colour"] != "s") {
			definition_error(definition, "PCA requires there to be a \"Colour\" associated with each sample. Did you forget <def name=\"Colour\" type=\"s\"/>?\n");
			return false;
		}
		if (!output.vars.has_key("Description") || output.vars["Description"] != "s") {
			definition_error(definition, "PCA requires there to be a \"Description\" associated with each sample. Did you forget <def name=\"Colour\" type=\"s\"/>?\n");
			return false;
		}

		var hasnumeric = false;
		foreach (var type in output.vars.values) {
			if (type == "i" || type == "d") {
				hasnumeric = true;
				break;
			}
		}
		if (!hasnumeric) {
			definition_error(definition, "You should have at least one numeric variable (i.e., type=\"d\" or type=\"i\") over which to do PCA.\n");
			return false;
		}
		output.add_target("pca/pca-biplot.pdf");
		return true;
	}
}
