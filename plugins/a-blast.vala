/**
 * Create a BLAST database for the sequence library
 *
 * Call formatdb to create a BLAST database and create a shell script to sensibly handle calling BLAST with decent options.
 */
class AXIOME.Analyses.BlastDatabase : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "blast";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 1);
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {

		output.add_target("blastdbs/nr.nhr");
		output.add_target("blastdbs/nr.nin");
		output.add_target("blastdbs/nr.nsq");
		output.add_target("blastdbs/r.nhr");
		output.add_target("blastdbs/r.nin");
		output.add_target("blastdbs/r.nsq");
		output.add_target("blastdbs/blast");
		output.add_rulef("blastdbs/blast: Makefile\n\t@echo Producing BLAST script...\n\t@test -d blastdbs || mkdir blastdbs\n\t@echo '#!/bin/sh' > blastdbs/blast\n\t@echo blastall -p blastn -d \\'%s/nr\\' '\"$$@\"' >> blastdbs/blast\n\t@chmod a+x blastdbs/blast\n\n", Shell.quote(realpath(output.dirname)));
		var title = definition->get_prop("title");
		if (title == null) {
			var name = Path.get_basename(output.dirname);
			if (name.has_suffix(".qiime")) {
				name = name.substring(0, name.length - 6);
			}
			title = @"$(name) 16S Sequence Library";
		}
		output.add_rulef("BLASTDB_NAME = %s\n\n", Shell.quote(title).replace("$", "$$"));
		var blastdbcmd = definition->get_prop("command");
		if (blastdbcmd != null) {
			switch (blastdbcmd.down()) {
				case "formatdb":
					output.add_rulef("BLASTDB_COMMAND = formatdb\n\n");
					break;
				case "makeblastdb":
					output.add_rulef("BLASTDB_COMMAND = makeblastdb\n\n");
					break;
				default:
					definition_error(definition, "The BLAST DB command \"%s\" is not valid. Valid options: formatdb, makeblastdb.\n", blastdbcmd);
					return false;
			}
		} else {
			//Default if no command provided
			output.add_rulef("BLASTDB_COMMAND = formatdb\n\n");
		}
		return true;
	}
}
