/**
 * This is an example processing rule.
 */
class AutoQIIME.Analyses.Example : RuleProcessor {
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
		return "example";
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
		return version(1, 3);
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
		message("Example!");
		output.add_target("example");
		return true;
	}
}
