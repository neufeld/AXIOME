using Gee;
/**
 * Assemble data using PANDAseq from Illumina files.
 *
 * Calls PANDAseq and pulls out specific indecies.
 */
class AutoQIIME.Sources.PandaSource : BaseSource {
	public override unowned string get_name() {
		return "panda";
	}
	public override unowned string ? get_include() {
		return null;
	}
	public override version introduced_version() {
		return version(1, 1);
	}
	public override bool is_only_once() {
		return false;
	}
	protected override string? get_sample_id(Xml.Node *sample) {
		var tag = sample-> get_prop("tag");
		if (tag == null) {
			definition_error(sample, "No tag specified.\n");
			return null;
		}
		if (tag.length != 6 && tag.length != 8) {
			definition_error(sample, "Tag is not 6 or 8 characters.\n");
			return null;
		}
		if (!is_sequence(tag)) {
			definition_error(sample, "Tag does not look like nucleotides.\n");
			return null;
		}
		return tag;
	}
	protected override bool generate_command(Xml.Node *definition, Collection<Sample> samples, StringBuilder command, Output output) {
		var forward = definition-> get_prop("forward");
		if (forward == null) {
			definition_error(definition, "Forward file not specified.\n");
			return false;
		}
		if (!FileUtils.test(forward, FileTest.EXISTS)) {
			definition_error(definition, "File \"%s\" does not exist.\n", forward);
			return false;
		}

		var reverse = definition-> get_prop("reverse");
		if (reverse == null) {
			definition_error(definition, "Reverse file not specified.\n");
			return false;
		}
		if (!is_valid_filename(forward) || !is_valid_filename(reverse)) {
			definition_error(definition, "Filename will cause Make to cry.\n");
			return false;
		}
		if (!FileUtils.test(reverse, FileTest.EXISTS)) {
			definition_error(definition, "File \"%s\" does not exist.\n", reverse);
			return false;
		}

		bool dashj = false;
		bool dashsix;
		bool domagic;
		bool convert;

		/* How we process this file depends on what version of CASAVA created the FASTQ files. The old ones need to be converted. We also need to know if they are bzipped so we can give the -j option to PANDAseq. */
		var version = definition-> get_prop("version");
		if (version == null) {
			definition_error(definition, "No CASAVA version specified.\n");
			return false;
		} else if (version == "1.3") {
			domagic = false;
			convert = true;
			dashsix = true;
		} else if (version == "1.4" || version == "1.5" || version == "1.6" || version == "1.7") {
			domagic = true;
			convert = false;
			dashsix = true;
		} else if (version == "1.8") {
			domagic = true;
			convert = false;
			dashsix = false;
		} else {
			definition_error(definition, "The version \"%s\" is not one that I recognise.\n", version);
			return false;
		}

		if (convert) {
			var oldforward = forward;
			var oldreverse = reverse;
			forward = "converted%x_1.fastq.bz2".printf(oldforward.hash());
			reverse = "converted%x_2.fastq.bz2".printf(oldreverse.hash());
			output.add_rule(@"$(forward): $(oldforward)\n\t@echo Coverting Illumina 1.3 file $(forward)...\n\t$$(V)$(FileCompression.for_file(oldforward).get_cat()) $(oldforward) | aq-oldillumina2fastq > $(forward)\n\n$(reverse): $(oldreverse)\n\t@echo Coverting Illumina 1.3 file $(forward)...\n\t$$(V)$(FileCompression.for_file(oldreverse).get_cat()) $(oldreverse) | aq-oldillumina2fastq > $(reverse)\n\n");
			domagic = false;
			dashj = true;
		}

		if (domagic) {
			dashj = FileCompression.for_file(forward) == FileCompression.BZIP;
		}

		output.add_sequence_source(forward);
		output.add_sequence_source(reverse);
		command.append_printf("pandaseq -N -f %s -r %s", Shell.quote(forward), Shell.quote(reverse));

		if (dashj) {
			command.append_printf(" -j");
		}
		if (dashsix) {
			command.append_printf(" -6");
		}
		add_primer(command, definition, "fprimer", 'p');
		add_primer(command, definition, "rprimer", 'q');
		var threshold = definition-> get_prop("threshold");
		if (threshold != null) {
			command.append_printf(" -t %s", Shell.quote(threshold));
		}
		command.append_printf(" -C validtag");
		foreach (var sample in samples) {
			command.append_printf(":%s", sample.tag);
		}
		return true;
	}
	void add_primer(StringBuilder command, Xml.Node *definition, string name, char arg) {
		var primer = get_primer(definition, definition-> get_prop(name));
		if (primer != null) {
			command.append_printf(" -%c %s", arg, primer);
		}
	}
}
