/**
 * Produce UniFrac-based multi-response permutation analysis
 */
class AXIOME.Analyses.UnifracMrpp : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "unifrac-mrpp";
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
			if (!output.vars.has_key("Colour") || output.vars["Colour"] != "s") {
			definition_error(definition, "Biplots require there to be a \"Colour\" associated with each sample.\n");
		}
		if (!output.vars.has_key("Description") || output.vars["Description"] != "s") {
			definition_error(definition, "Biplots require there to be a \"Description\" associated with each sample.\n");
		}

		string flavour;
		var size = definition-> get_prop("size");
		if (size == null) {
			flavour = "";
		} else if (size == "auto") {
			flavour = "_auto";
		} else {
			int v = int.parse(size);
			if (v < 1) {
				definition_error(definition, "Cannot rareify to a size of \"%s\". Use a positive number or \"auto\".\n", size);
				return false;
			}
			flavour = "_%d".printf(v);
			output.make_rarefied(v);
		}

		output.add_rule(@"mrpp-unifrac$(flavour).txt mrpp-unifrac$(flavour).pdf: beta_div$(flavour)/weighted_unifrac_otu_table$(flavour).txt\n\t$$(V)aq-mrpp-unifrac $(flavour)\n\n");
		output.add_target(@"mrpp-unifrac$(flavour).txt");
		output.add_target(@"mrpp-unifrac$(flavour).pdf");
		return true;
	}
}
