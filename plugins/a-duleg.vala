/**
 * Compute Dufrene-Legendre indicator species analysis in R
 */
class AXIOME.Analyses.DuLegStats : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "duleg";
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
		var plimit = definition->get_prop("p");
		double p;
		string pstr;
		string praw;
		if (plimit != null) {
			if (!double.try_parse(plimit, out p) || p > 1 || p < 0) {
				definition_error(definition, "The p value \"%s\" is not valid. Specify a value between 0 and 1.\n", plimit);
				return false;
			}
			praw = plimit.to_string();
			pstr = plimit.replace(".","");
		} else {
			//Defaults
			p = 0.05;
			praw = "0.05";
			pstr = "005";
		}
			output.add_target("duleg/duleg_%s.txt".printf(pstr));
			if ( is_version_at_least(1,5) ) {
				output.add_rulef("duleg/duleg_%s.txt: otu_table.txt otu_table_with_sequences.txt mapping.txt\n\t@echo Computing Dufrene-Legendre stats for p=%f\n\t$(V)aq-duleg -B %s\n\t$(V)aq-otudulegmerge duleg_%s.txt otu_table_with_sequences.txt\n\t$(V)test -d duleg || mkdir duleg\n\t$(V)mv duleg_* duleg\n\n", pstr, p, praw, pstr);
			} else {
				output.add_rulef("duleg/duleg_%s.txt: otu_table.txt otu_table_with_sequences.txt mapping.txt\n\t@echo Computing Dufrene-Legendre stats for p=%f\n\t$(V)aq-duleg %s\n\t$(V)aq-otudulegmerge duleg_%s.txt otu_table_with_sequences.txt\n\t$(V)test -d duleg || mkdir duleg\n\t$(V)mv duleg_* duleg\n\n", pstr, p, praw, pstr);
			}
		return true;
	}
}
