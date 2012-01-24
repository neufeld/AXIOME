/**
 * Perform a chimera check with uchime
 */
class AutoQIIME.Analyses.UchimeCheck : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "uchime";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		var profile = definition-> get_prop("profile");
		if (profile != null) {
			switch (profile.down()) {
			case "v3-stringent" :
				output["UCHIMEFLAGS"] = "--mindiv 1.5 --minh 5";
				break;
			case "v3-relaxed" :
				output["UCHIMEFLAGS"] = "--mindiv 1 --minh 2.5";
				break;
			default :
				definition_error(definition, "Unknown profile \"%s\".\n", profile);
				return false;
			}
		}
		for (var i = 0; i < output.sequence_preparations; i++) {
			output.add_target("chimeras%d.uchime".printf(i));
		}
		return true;
	}
}
