/**
 * Runs PERMDISP2 algorithm via vegan::betadisper
 */
class AXIOME.Analyses.BetaDisper : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "betadisper";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 6);
	}
	public override bool is_only_once() {
		return false;
	}
	public override bool process(Xml.Node *definition, Output output) {
		var method = definition->get_prop("method");
		string[] methods = {"manhattan", "euclidean", "canberra", "bray", "kulczynski", "jaccard", "gower", "altGower", "morisita", "horn", "mountford", "raup", "binomial", "chao", "cao"};

		if ( method != null ) {
			if ( ! ( method in methods ) ) {
				definition_error(definition, "Unrecognized PCoA dissimilarity method. Choose one of: manhattan, euclidean, canberra, bray, kulczynski, jaccard, gower, altGower, morisita, horn, mountford, raup , binomial, chao, cao.\n");
				return false;
			}
		} else {
			method = "bray";
		}

		output.add_target("betadisper/betadisper-%s.pdf".printf(method));
		output.add_target("betadisper/betadisper-%s.txt".printf(method));
		if ( is_version_at_least(1,5) || output.pipeline.to_string() == "mothur" ) {
			output.add_rulef("betadisper/betadisper-%s.pdf betadisper/betadisper-%s.txt: mapping.txt otu_table_auto.tab\n\t@echo Computing Beta Dispersion PERMDISP2 with method '%s'\n\t$(V)aq-betadisper -i otu_table_auto.tab -o betadisper -m mapping.txt -d %s\n\n", method, method, method, method);
		} else {
    output.add_rulef("betadisper/betadisper-%s.pdf betadisper/betadisper-%s.txt: mapping.txt otu_table_auto.txt\n\t@echo Computing Beta Dispersion PERMDISP2 with method '%s'\n\t$(V)aq-betadisper -i otu_table_auto.txt -o betadisper -m mapping.txt -d %s\n\n", method, method, method, method);
		}
		return true;
	}
}
