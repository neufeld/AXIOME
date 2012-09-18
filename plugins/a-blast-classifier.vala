/**
 * Controls the flags sent to RDP classifier
 */
class AXIOME.Analyses.BLASTClassifier : RuleProcessor {
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
		return "blast-classifier";
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
			definition_error(definition, "mothur pipeline does not use blast-classifier. Please remove blast-classifier plugin from .ax file before continuing.\n");
			return false;
		} else if (pipeline.to_string() == "qiime") {
			string blast_flags = "";

			var e_val = definition->get_prop("e");
			if (e_val != null) {
				double e_val_double = double.parse(e_val);
				if (e_val_double >= 1 || e_val_double <= 0) {
					definition_error(definition, "e value must be between 0 and 1. Value given: \"%s\".\n", e_val);
					return false;
				} else {
					blast_flags += "-e ".concat(e_val, " ");
				}
			}

			var training_file = definition->get_prop("taxfile");
			if (training_file != null) {
				blast_flags += "-t ".concat(training_file, " ");
			}
			var seq_file = definition->get_prop("seqfile");
			if (seq_file != null) {
				blast_flags += "-r ".concat(seq_file, " ");
			}
			var db_file = definition->get_prop("db");
			if (db_file != null) {
				blast_flags += "-b ".concat(db_file, " ");
			}
			output.add_rulef("BLAST_CLASSIFIER_FLAGS = %s\n\n", blast_flags);
		}
		return true;
	}
}
