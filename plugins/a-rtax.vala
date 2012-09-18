/**
 * Controls the flags sent to RDP classifier
 */
class AXIOME.Analyses.Rtax : RuleProcessor {
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
		return "rtax";
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
			definition_error(definition, "mothur pipeline does not use Rtax. Please remove Rtax plugin from .ax file before continuing.\n");
			return false;
		} else if (pipeline.to_string() == "qiime") {
			string rtax_flags = "";

			var training_file = definition->get_prop("taxfile");
			if (training_file != null) {
				rtax_flags += "-t ".concat(training_file, " ");
			} else {
				definition_error(definition, "Error: taxfile must be specified when using Rtax classifier.\n");
				return false;
			}
			var seq_file = definition->get_prop("seqfile");
			if (seq_file != null) {
				rtax_flags += "-r ".concat(seq_file, " ");
			} else {
				definition_error(definition, "Error: seqfile must be specified when using Rtax classifier.\n");
				return false;
			}
			var read_1_file = definition->get_prop("read-1");
			if (read_1_file != null) {
				rtax_flags += "--read_1_seqs_fp ".concat(read_1_file, " ");
			} else {
				definition_error(definition, "Error: read-1 must be specified when using Rtax classifier.\n");
				return false;
			}
			var read_2_file = definition->get_prop("read-2");
			if (read_2_file != null) {
				rtax_flags += "--read_2_seqs_fp ".concat(read_2_file, " ");
			} else {
				definition_error(definition, "Error: read-2 must be specified when using Rtax classifier.\n");
				return false;
			}

			output.add_rulef("RTAX_CLASSIFIER_FLAGS = %s\n\n", rtax_flags);
		}
		return true;
	}
}
