/**
 * This is an example processing rule.
 */
class AXIOME.Analyses.ExcludeTaxa : RuleProcessor {
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
		return "exclude-taxonomy";
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
			definition_error(definition, "Exclude taxa not available for mothur. Sorry! Please remove from .ax file before continuing.\n");
			return false;
		} else if (pipeline.to_string() == "qiime") {
			var excludes = definition->get_prop("taxa");
			var excludeslist = excludes.split(",");
			output.add_rulef("TAXA_EXCLUDE_FILE := assigned_taxonomy/seq.fasta_rep_set_tax_assignments.txt\n");
			bool first = true;
			string out_str = "";
			foreach (string item in excludeslist) {
				if (first) {
					out_str += "$$0 ~ /" + item.strip() +  "/ ";
					first = false;
				} else {
					out_str += "|| $$0 ~ /" + item.strip() + "/ ";
				}
			}
			output.add_rulef("TAXA_EXCLUDE_STR := %s\n", out_str);
			output.add_rulef("OTU_EXCUDE := -e exclude_otus.list\n");
			output.add_rulef("OTU_EXCLUDE_FILE := exclude_otus.list\n\n");
		}
		return true;
	}
}
