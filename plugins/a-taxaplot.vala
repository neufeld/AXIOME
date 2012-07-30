/**
 * Produce taxa plots using QIIME
 *
 * Creates bar plots and area charts using the OTU table
 */
class AXIOME.Analyses.TaxaPlot : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "taxaplot";
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
		var pipeline = output.pipeline;
		if (pipeline.to_string() == "mothur") {
			stderr.printf("Warning: Taxaplot plugin uses QIIME. Only use if QIIME is installed.\n");
		}
		output.add_target("taxaplot/taxa_summary_plots/area_charts.html");
		output.add_target("taxaplot/taxa_summary_plots/bar_charts.html");
		output.add_rule("taxaplot/taxa_summary_plots/area_charts.html taxaplot/taxa_summary_plots/bar_charts.html: otu_table.txt mapping.txt\n\t@echo Creating taxa plots...\n\t$(V)test ! -d taxaplot || rm -rf taxaplot\n\t$(V)$(QIIME_PREFIX)summarize_taxa_through_plots.py -i otu_table.txt -o taxaplot -m mapping.txt\n\n");
		return true;
	}
}
