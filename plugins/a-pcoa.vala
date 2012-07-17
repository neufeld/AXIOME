/**
 * Produce principle coordinate analysis using R
 *
 * Do prinicpal coordinate analysis on the taxa and the other (numeric) variables specified.
 */
class AXIOME.Analyses.PrincipalCoordinateAnalysis : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "pcoa";
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
		var method = definition->get_prop("method");
		string[] methods = {"manhattan", "euclidean", "canberra",	"bray", "kulczynski", "jaccard", "gower", "altGower", "morisita", "horn",	"mountford", "raup", "binomial", "chao", "cao"};

		if ( method != null ) {
			if ( ! ( method in methods ) ) {
				definition_error(definition, "Unrecognized PCoA dissimilarity method. Choose one of: manhattan, euclidean, canberra, bray, kulczynski, jaccard, gower, altGower, morisita, horn, mountford, raup , binomial, chao, cao.\n");
				return false;
			}
		} else {
			method = "bray";
		}

		if (!output.vars.has_key("Colour") || output.vars["Colour"] != "s") {
			definition_error(definition, "PCoA requires there to be a \"Colour\" associated with each sample. Did you forget <def name=\"Colour\" type=\"s\"/>?\n");
			return false;
		}

		if (!output.vars.has_key("Description") || output.vars["Description"] != "s") {
			definition_error(definition, "PCoA requires there to be a \"Description\" associated with each sample. Did you forget <def name=\"Description\" type=\"s\"/>?\n");
			return false;
		}

		output.add_target("pcoa-%s-biplot.pdf".printf(method));
		if ( is_version_at_least(1,5) ) {
			output.add_rulef("pcoa-%s-biplot.pdf: mapping.txt otu_table.txt headers.txt\n\t@echo Computing PCoA analysis using method '%s'\n\t$(V)aq-pcoa -B %s\n\n", method, method, method);
		} else {
				output.add_rulef("pcoa-%s-biplot.pdf: mapping.txt otu_table.txt headers.txt\n\t@echo Computing PCoA analysis using method '%s'\n\t$(V)aq-pcoa %s\n\n", method, method, method);
		}
		return true;
	}
}
