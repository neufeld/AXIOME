/**
 * Create a BLAST database for the sequence library
 *
 * Call formatdb to create a BLAST database and create a shell script to sensibly handle calling BLAST with decent options.
 */
class AutoQIIME.Analyses.BlastDatabase : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "blast";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {

		output.add_target("nr.nhr");
		output.add_target("nr.nin");
		output.add_target("nr.nsq");
		output.add_target("blast");
		output.add_rule("blast: Makefile\n\t@echo '#!/bin/sh' > blast\n\t@echo blastall -p blastn -d \\'%s/nr\\' '\"$$@\"' >> blast\n\tchmod a+x blast\n\n", Shell.quote(realpath(output.dirname)));
		var title = definition->get_prop("title");
		if (title == null) {
			var name = Path.get_basename(output.dirname);
			if (name.has_suffix(".qiime")) {
				name = name.substring(0, name.length - 6);
			}
			title = @"$(name) 16S Sequence Library";
		}
		output.add_rule("BLASTDB_NAME = %s\n\n", title);
		return true;
	}
}
