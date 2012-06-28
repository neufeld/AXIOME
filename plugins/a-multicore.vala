/**
 * This is an example processing rule.
 */
class AutoQIIME.Analyses.Multicore : RuleProcessor {
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
		return "multicore";
	}
	/*
	 * When generating the Makefile, is there a secondary Makefile that should be included?
	 */
	public override unowned string ? get_include() {
		return null;
	}

	/**
	 * What version of AutoQIIME was this feature introduced in?
	 *
	 * You should set this to the current version of AutoQIIME when you develop a plugin and never change it.
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
		var num_cores = definition->get_prop("num-cores");
		if (num_cores != null) {
			if (int.parse(num_cores) < 1) {
			  definition_error(definition, "Unknown value for number of cores \"%s\".\n", num_cores);
				return false;
			} else {
				output.add_rulef("NUM_CORES := %s\n", num_cores);
			}
		} else {
			definition_error(definition, "When using multicore plugin, the number of cores must be specified with num-cores=\"number\".");
			return false;
    }

		output.add_rulef("MULTICORE := TRUE\n\n");
		return true;
	}
}
