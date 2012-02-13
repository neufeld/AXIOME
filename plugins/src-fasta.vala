using Gee;
/**
 * Copy data from existing FASTA files
 *
 * Read a FASTA file into seq.fasta and pull sequences with ids matching specific regular expressions.
 */
class AutoQIIME.Sources.FastaSource : BaseSource {
	public override RuleType get_ruletype() {
		return RuleType.SOURCE;
	}
	public override unowned string get_name() {
		return "fasta";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 2);
	}
	public override bool is_only_once() {
		return false;
	}

	protected override string? get_sample_id(Xml.Node *sample) {
		var regexstr = sample-> get_prop("regex");
		if (regexstr == null || regexstr == "") {
			definition_error(sample, "Missing regular expression. Ignorning, mumble, mumble.\n");
			return null;
		}
		try {
			new Regex(regexstr);
			return regexstr;
		} catch(RegexError e) {
				definition_error(sample, "Invalid regex %s. If you want everything, just make regex=\".\" or go read about the joy of POSIX regexs.\n", regexstr);
				return null;
		}
	}
	protected override bool generate_command(Xml.Node *definition, Collection<Sample> samples, StringBuilder command, Output output) {
		var file = definition-> get_prop("file");
		if (file == null) {
			definition_error(definition, "FASTA file not specified.\n");
			return false;
		}
		if (!is_valid_filename(file)) {
			definition_error(definition, "Filename will cause Make to cry.\n");
			return false;
		}
		if (!FileUtils.test(file, FileTest.EXISTS)) {
			definition_error(definition, "File \"%s\" does not exist.\n", file);
			return false;
		}

		output.add_sequence_source(file);
		command.append_printf("%s %s", FileCompression.for_file(file).get_cat(), Shell.quote(file));
		return true;
	}
}
