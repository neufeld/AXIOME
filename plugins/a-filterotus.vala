/**
 * This is an example processing rule.
 */
class AXIOME.Analyses.FilterOTUs : RuleProcessor {
	/*
	 * Is this a new kind of analysis or a new source of sequence data?
	 */
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	/*
	 * What is the XML tag associated with this rule. Each XML tag needs its own rule, though you must process child tags, if desired.
	 */
	public override unowned string get_name() {
		return "filter-otu-table";
	}
	/*
	 * When generating the Makefile, is there a secondary Makefile that should be included?
	 */
	public override unowned string ? get_include() {
		return null;
	}

	/**
	 * What version of AXIOME was this feature introduced in?
	 *
	 * You should set this to the current version of AXIOME when you develop a plugin and never change it.
	 */
	public override version introduced_version() {
		return version(1, 6);
	}
	/*
	 * Can this rule be included multiple times? Each tag must generate some non-mutually infering set of Make rules.
	 */
	public override bool is_only_once() {
		return true;
	}

	/*
	 * Called for each tag, passed as defintion, to add rules to the nascent Makefile using Output.
	 */
	public override bool process(Xml.Node *definition, Output output) {
		var pipeline = output.pipeline;
		if (pipeline.to_string() == "mothur") {
			definition_error(definition, "Filtering OTU table not available for mothur. Sorry! Please remove from .ax file before continuing.\n");
			return false;
		} else if (pipeline.to_string() == "qiime") {
			var minseqs = definition->get_prop("min-seqs");
			var maxseqs = definition->get_prop("max-seqs");
			var minsamples = definition->get_prop("min-samples");
			var maxsamples = definition->get_prop("max-samples");
			output.add_rulef("FILTEROTUTABLE := TRUE\n");
			if (minseqs == null && maxseqs == null && minsamples == null && maxsamples == null) {
				definition_error(definition, "Need to have at least one attribute from the following: min-seqs, max-seqs, min-samples, max-samples.\n");
				return false;
			}
			if (minseqs != null) {
				output.add_rulef("MIN_SEQ_IN_OTU = %s\n", minseqs);
			}
			if (maxseqs != null) {
			output.add_rulef("MAX_SEQ_IN_OTU = %s\n", maxseqs);
			}
			if (minsamples != null) {
			output.add_rulef("MIN_SAMPLES_IN_OTU = %s\n", minsamples);
			}
			if (maxsamples != null) {
			output.add_rulef("MAX_SAMPLES_IN_OTU = %s\n", maxsamples);
			}

		}
		return true;
	}
}
