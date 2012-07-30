/**
 * Controls the flags sent to RDP classifier
 */
class AXIOME.Analyses.RDP : RuleProcessor {
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
		return "rdp";
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
		return version(1, 5);
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
			definition_error(definition, "mothur pipeline does not use RDP. Please remove RDP plugin from .ax file before continuing.\n");
			return false;
		} else if (pipeline.to_string() == "qiime") {
			string rdp_flags = "";

			var rdp_confidence = definition->get_prop("confidence");
			if (rdp_confidence != null) {
				double conf_val = double.parse(rdp_confidence);
				if (conf_val >= 1 || conf_val <= 0) {
					definition_error(definition, "RDP confidence must be between 0 and 1. Value given: \"%s\".\n", rdp_confidence);
					return false;
				} else {
					rdp_flags += "-c ".concat(rdp_confidence, " ");
				}
			}

			var training_file = definition->get_prop("taxfile");
			if (training_file != null) {
				rdp_flags += "-t ".concat(training_file, " ");
			}
			var seq_file = definition->get_prop("seqfile");
			if (seq_file != null) {
				rdp_flags += "-r ".concat(seq_file, " ");
			}
			output.add_rulef("RDP_CLASSIFIER_FLAGS = %s\n\n", rdp_flags);
		}
		return true;
	}
}
