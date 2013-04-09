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

		var ellipsoid_conf = definition->get_prop("ellipsoid-confidence");
		double e;
		if (ellipsoid_conf != null) {
			if (!double.try_parse(ellipsoid_conf, out e) || e > 1 || e < 0) {
				definition_error(definition, "The confidence value \"%s\" is not valid. Specify a value between 0 and 1.\n", ellipsoid_conf);
				return false;
			}
		}
		/*if (!output.vars.has_key("Colour") || output.vars["Colour"] != "s") {
			definition_error(definition, "PCoA requires there to be a \"Colour\" associated with each sample. Did you forget <def name=\"Colour\" type=\"s\"/>?\n");
			return false;
		}*/

		if (!output.vars.has_key("Description") || output.vars["Description"] != "s") {
			definition_error(definition, "PCoA requires there to be a \"Description\" associated with each sample. Did you forget <def name=\"Description\" type=\"s\"/>?\n");
			return false;
		}

		output.add_target("pcoa/pcoa-%s-biplot.pdf".printf(method));
		if ( is_version_at_least(1,5) || output.pipeline.to_string() == "mothur" ) {
			output.add_rulef("pcoa/pcoa-%s-biplot.pdf: mapping.txt otu_table_auto.tab headers.txt\n\t@echo Computing PCoA analysis using method '%s'\n\t$(V)aq-pcoa -i otu_table_auto.tab -o pcoa -m mapping.txt -e mapping.extra -t headers.txt -d %s", method, method, method);
		} else {
				output.add_rulef("pcoa/pcoa-%s-biplot.pdf: mapping.txt otu_table_auto.txt headers.txt\n\t@echo Computing PCoA analysis using method '%s'\n\t$(V)aq-pcoa -i otu_table_auto.txt -o pcoa -m mapping.txt -e mapping.extra -t headers.txt -d %s", method, method, method);
		}
		if (ellipsoid_conf != null) {
				output.add_rulef(" -p %s", ellipsoid_conf);
		}
		output.add_rulef("\n\n");
		return true;
	}
}
