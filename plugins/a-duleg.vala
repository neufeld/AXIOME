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
		var plot = definition->get_prop("plot");
		if (plot != null) {
			if (plot.down() == "true" || plot.down() == "t") {
				output.add_rule("PLOT_DULEG=TRUE\n");
			}
		}
		var plotlevels = definition->get_prop("plot-levels");
		if (plotlevels == null) {
			plotlevels = "6";
		}
		output.add_target("duleg/duleg_%s.txt".printf(pstr));
		if ( is_version_at_least(1,5) || output.pipeline.to_string() == "mothur" ) {
			output.add_rulef("duleg/duleg_%s.txt: otu_table.tab otu_table_with_sequences.txt mapping.txt\n\t@echo Computing Dufrene-Legendre stats for p=%f\n\t$(V)test -d duleg || mkdir duleg\n\t$(V)aq-duleg -p %s -i otu_table.tab -o duleg -m mapping.txt\n\t$(V)aq-otudulegmerge duleg/duleg_%s.txt otu_table_with_sequences.txt duleg\nifdef PLOT_DULEG\n\t@echo Creating Duleg plots...\n\t$(V)test ! -d duleg_plots || rm -rf duleg_plots\n\tfind duleg/*.tab -exec aq-dulegplot -i {} -o duleg_plots/ -m mapping.txt -l %s \\;\nendif\n\n", pstr, p, praw, pstr, plotlevels);
		} else {
			output.add_rulef("duleg/duleg_%s.txt: otu_table.txt otu_table_with_sequences.txt mapping.txt\n\t@echo Computing Dufrene-Legendre stats for p=%f\n\t$(V)test -d duleg || mkdir duleg\n\t$(V)aq-duleg -p %s -i otu_table.txt -o duleg -m mapping.txt\n\t$(V)aq-otudulegmerge duleg/duleg_%s.txt otu_table_with_sequences.txt duleg\nifdef PLOT_DULEG\n\t@echo Creating Duleg plots...\n\t$(V)test ! -d duleg_plots || rm -rf duleg_plots\n\tfind duleg/*.tab -exec aq-dulegplot -i {} -o duleg_plots/ -m mapping.txt -l %s \\;\nendif\n\n", pstr, p, praw, pstr, plotlevels);
		}
		return true;
	}
}
