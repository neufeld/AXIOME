using Gee;
using Xml;

namespace AutoQIIME {

	HashMap<string, string> primers;
	[CCode(cname = "DATADIR")]
	extern const string DATADIR;
	[CCode(cname = "MODDIR")]
	extern const string MODDIR;
	[CCode(cname = "BINDIR")]
	extern const string BINDIR;

	/**
	 * Create a path for a file inside the bin directory where AutoQIIME was installed.
	 *
	 * e.g., bin_dir("aq-nmf") = "/usr/local/bin/aq-nmf"
	 */
	public string bin_dir(string filename) {
		return Path.build_filename(BINDIR, filename);
	}

	/**
	 * Create a path for a file inside the shared directory where AutoQIIME was installed.
	 *
	 * e.g., data_dir("nmf.R") = "/usr/local/share/autoqiime/nmf.R"
	 */
	public string data_dir(string filename) {
		return Path.build_filename(DATADIR, filename);
	}

	/**
	 * Convenience class for new sequence sources.
	 *
	 * To create a rule responsible for drawing sequences out of some entity (a file, program, or database), create a subclass.
	 *
	 * A sequence source is expected to provide a shell command to extract sequences and provide them in FASTA format. Each sample must be associated with a regular expression capable of extracting matching sequences from the FASTA.
	 */
	public abstract class BaseSource : RuleProcessor {
		/**
		 * {@inheritDoc}
		 */
		public override RuleType get_ruletype() {
			return RuleType.SOURCE;
		}
		/**
		 * Gets a primer, by name, from the primer database.
		 *
		 * Primers may be either a length, a name, or a string of nucleotides. Names are resolved using AutoQIIME's primer database. If a primer name begins with a #, the length of the named primer will be returned, instead of the primer itself.
		 */
		protected string? get_primer(Xml.Node *definition, string? primer) {
			if (primer != null) {
			var up_primer = primer.up();
				if (up_primer[0] == '#') {
					up_primer = up_primer.substring(1);
					if (primers.has_key(up_primer)) {
						return primers[up_primer].length.to_string();
					} else {
						definition_error(definition, "Unknown primer %s. Ignorning, mumble, mumble.\n", primer);
						return null;
					}
				} else if (primers.has_key(up_primer)) {
					return Shell.quote(primers[up_primer]);
				} else if (Regex.match_simple("^\\d+$", up_primer) || is_sequence(up_primer)) {
				return Shell.quote(up_primer);
				} else {
					definition_error(definition, "Invalid primer %s. Ignorning, mumble, mumble.\n", primer);
					return null;
				}
			}
			return null;
		}
		/**
		 * Produce the shell command needed to provide the sequence to an output pipe in FASTA format.
		 *
		 * For a FASTA file, this is trivially "cat".
		 * @param defintion the XML element causing this ruckus
		 * @param samples the samples that are expected to be extracted from this data source
		 * @param command where to write the command
		 * @param output the nascent Makefile, if any extra rules are needed
		 * @return whether the command is valid
		 */
		protected abstract bool generate_command(Xml.Node *definition, Collection<Sample> samples, StringBuilder command, Output output);

		/**
		 * For a sample XML tag, produce a valid regular expression that will appear in the FASTA headers for sequences belonging to this sample
		 * @return if null, the sample is invalid; otherwise, a regular expression to filter the FASTA stream.
		 */
		protected abstract string? get_sample_id(Xml.Node *sample);
		public override bool process(Xml.Node *definition, Output output) {
			var samples = new HashMap<string, Sample>();
			for (Xml.Node *sample = definition-> children; sample != null; sample = sample-> next) {
				if (sample-> type != Xml.ElementType.ELEMENT_NODE) {
					continue;
				}
				if (sample-> name != "sample") {
					definition_error(definition, "Invalid element %s. Ignorning, mumble, mumble.\n", sample-> name);
					continue;
				}
				var tag = get_sample_id(sample);
				if (tag == null || tag == "") {
					continue;
				}
				if (samples.has_key(tag)) {
					definition_error(definition, "Duplicated identifer %s on %s:%d. Skipping.\n", tag, sample-> doc-> url, sample-> line);
					continue;
				}
				var sample_obj = output.add_sample(tag, sample);
				samples[tag] = sample_obj;
				var limit = sample-> get_prop("limit");
				if (limit != null) {
					var limitval = int.parse(limit);
					if (limitval > 0) {
						samples[tag].limit = limitval;
					}
				}
			}

			var command = new StringBuilder();
			if (!generate_command(definition, samples.values.read_only_view, command, output)) {
				return false;
			}
			output.prepare_sequences(command.str, samples.values);
			return true;
		}
	}

	/**
	 * Represents a sample from the input file, across all sequence sources.
	 */
	public class Sample : Object {
		/**
		 * The XML sample tag that generated this sample.
		 */
		public Xml.Node *xml { get; internal set; }
		/**
		 * The regular expression used the extract this sample from the source's FASTA stream.
		 */
		public string tag { get; internal set; }
		/**
		 * The maximum number of sequences to allow from this sample, or all if non-positive.
		 */
		public int limit { get; internal set; }
		/**
		 * The QIIME library identifier associated with this sample.
		 */
		public int id { get; internal set; }
	}

	/**
	 * Type of stanzas in the XML input document.
	 */
	public enum RuleType { DEFINITON, SOURCE, ANALYSIS }

	/**
	 * Rule processor interface for analyses and data sources
	 */
	public abstract class RuleProcessor : Object {
		/**
		 * The type of the rule. This determines the order in which rules must appear.
		 */
		public abstract RuleType get_ruletype();
		/**
		 * Name of the XML tag for this sequence source.
		 */
		public abstract unowned string get_name();
		/**
		 * Path to a file that must be included in the Makefile.
		 */
		public abstract unowned string ? get_include();
		/**
		 * Can this directive be included multiple times in a configuration file?
		 */
		public abstract bool is_only_once();
		/**
		 * Create a processing stanza for the supplied definition.
		 */
		public abstract bool process(Xml.Node *definition, Output output);
	}

	/**
	 * Check if a sequence is a valid (degenerate) nucleotide sequence.
	 */
	public bool is_sequence(string sequence) {
		return Regex.match_simple("^[ACGTKMSWRYBDHV]*$", sequence);
	}

	/**
	 * Friendly names for taxnomic levels as used by QIIME/RDP
	 */
	public enum TaxonomicLevel {
		LIFE = 1,
		DOMAIN = 2,
		PHYLUM = 3,
		CLASS = 4,
		ORDER = 5,
		FAMILY = 6,
		GENUS = 7,
		SPECIES = 8,
		STRAIN = 9;
		public static TaxonomicLevel ? parse(string name) {
		  var enum_class = (EnumClass) typeof(TaxonomicLevel).class_ref();
		  var nick = name.down().replace("_", "-");
		  unowned GLib.EnumValue ? enum_value = enum_class.get_value_by_nick(nick);
		  if (enum_value != null) {
		    TaxonomicLevel value = (TaxonomicLevel) enum_value.value;
		    return value;
		  }
		  return null;
		}
		public string to_string() {
		  return ((EnumClass) typeof (TaxonomicLevel).class_ref()).get_value(this).value_nick;
		}
	}

	/**
	 * Output processor responsible for collecting all information needed to generate the Makefile and mapping.txt
	 */
	public class Output : Object {
		/**
		 * The output directory name.
		 */
		public string dirname { get; private set; }
		StringBuilder makerules;
		/**
		 * All the samples currently processed in the file.
		 *
		 * They can be from multiple sources.
		 */
		public Gee.List<Sample> known_samples {
			owned get {
				return samples.read_only_view;
			}
		}
		ArrayList<Sample> samples;
		StringBuilder seqrule;
		StringBuilder seqsources;
		int sequence_preparations;
		string sourcefile;
		/**
		 * The defined variables and their types.
		 *
		 * (i.e., all the def tags)
		 */
		public HashMap<string, string> vars { get; private set; }
		Set<string> summarized_otus;
		StringBuilder targets = new StringBuilder();
		ArrayList<Xml.Doc*> doc_list;

		internal Output(string dirname, string sourcefile) {
			this.dirname = dirname;
			this.sourcefile = realpath(sourcefile);

			sequence_preparations = 0;
			makerules = new StringBuilder();
			samples = new ArrayList<Sample>();
			seqrule = new StringBuilder();
			seqrule.printf("\ttest ! -f seq.fasta || rm seq.fasta\n");
			seqsources = new StringBuilder();
			summarized_otus = new HashSet<string>();
			targets = new StringBuilder();
			vars = new HashMap<string, string>();
			doc_list = new ArrayList<Xml.Doc*>();
		}

		/**
		 * Output the mapping.txt file in the appropriate directory.
		 */
		internal bool generate_mapping() {
			var mapping = new StringBuilder();
			var extra = new StringBuilder();
			var headers = new StringBuilder();
			if (mapping == null) {
				stderr.printf("%s: Cannot create mapping file.\n", dirname);
				return false;
			}
			mapping.append_printf("#SampleID");
			extra.append_printf("#SampleID");
			var first = true;
			foreach (var entry in vars.entries) {
				var isextra = entry.key == "Colour" || entry.key == "Description";
				(isextra ? extra : mapping).append_printf("\t%s", entry.key);
				if (!isextra) {
					if (!first) {
						headers.append_c('\t');
					}
					headers.append(entry.value == "i" || entry.value == "d" ? "TRUE" : "FALSE");
					first = false;
				}
			}
			mapping.append_c('\n');
			extra.append_c('\n');
			headers.append_c('\n');
			foreach (var sample in samples) {
				mapping.append_printf("%d", sample.id);
				extra.append_printf("%d", sample.id);
				foreach (var entry in vars.entries) {
					var prop = sample.xml-> get_prop(entry.key);
					if (prop == null) {
						stderr.printf("%s: %d: Missing attribute %s.\n", sample.xml-> doc-> url, sample.xml-> line, entry.key);
						(entry.key == "Colour" || entry.key == "Description" ? extra : mapping).append_printf("\t");
					} else {
						if (entry.key == "Colour" || entry.key == "Description") {
							extra.append_printf("\t%s", prop);
						} else if (entry.value == "s") {
							/* For strings, we are going to side step the Variant stuff because we want the XML to look like foo="bar" rather than foo="'bar'" as Variants would have it. */
							mapping.append_printf("\t%s", prop);
						} else {
							try {
								var value = Variant.parse(new VariantType(entry.value), prop);
								mapping.append_printf("\t%s", value.print(false));
							} catch(GLib.VariantParseError e) {
								stderr.printf("%s: %d: Attribute %s:%s = \"%s\" is not of the correct format.\n", sample.xml-> doc-> url, sample.xml-> line, entry.key, entry.value, prop);
								mapping.append_c('\t');
							}
						}
					}
				}
				mapping.append_c('\n');
				extra.append_c('\n');
			}
			return update_if_different("mapping.txt", mapping.str) && update_if_different("mapping.extra", extra.str) && update_if_different("headers.txt", headers.str);
		}

		bool update_if_different(string filename, string newcontents) {
			var filepath = Path.build_filename(dirname, filename);
			if (FileUtils.test(filepath, FileTest.IS_REGULAR)) {
				string current;
				try {
					if (FileUtils.get_contents(filepath, out current) && current == newcontents) {
						return true;
					}
				} catch(FileError e) {
					/* We probably don't care. We'll just attempt to write. */
				}
			}
			try {
				return FileUtils.set_contents(filepath, newcontents);
			} catch(FileError e) {
				stderr.printf("%s: %s\n", filepath, e.message);
			}
			return false;
		}

		/**
		 * Output the Makefile file in the appropriate directory.
		 */
		internal bool generate_makefile(RuleLookup lookup) {
			var now = Time.local(time_t());
			var makefile = FileStream.open(Path.build_filename(dirname, "Makefile"), "w");
			if (makefile == null) {
				stderr.printf("%s: Cannot create Makefile.\n", dirname);
				return false;
			}

			makefile.printf("# Generated by %s from %s on %s\n# Modify at your own peril!\n\nall: Makefile mapping.txt otu_table.txt %s\n\n", PACKAGE, sourcefile, now.to_string(), targets.str);
			makefile.printf("Makefile mapping.txt: %s\n\tautoqiime $<\n\n", sourcefile);
			makefile.printf("SEQSOURCES = %s\n\nseq.fasta:$(SEQSOURCES)\n%s\n", seqsources.str, seqrule.str);
			makefile.printf("%s\n.PHONY: all\n\ninclude %s/aq-base\n", makerules.str, BINDIR);
			lookup.print_include(makefile);
			makefile = null;
			return true;
		}

		/**
		 * Generate a summarized OTU table
		 *
		 * @param level the taxonomic level at which to summarise.
		 * @param flavour an optional part of the filename if you have some extra information to convey (e.g., rarefication depth).
		 */
		public void make_summarized_otu(TaxonomicLevel level, string flavour) {
			var taxname = level.to_string();
			var taxindex = (int) level;
			var type = @"$(taxname)$(flavour)";
			if (!(type in summarized_otus)) {
				summarized_otus.add(type);
				if (is_version_at_least(1, 3)) {
					makerules.append(@"otu_table_summarized_$(taxname)$(flavour).txt: otu_table$(flavour).txt\n\t$$(QIIME_PREFIX)summarize_taxa.py -i otu_table$(flavour).txt -L $(taxindex) -o . -a\n\tmv otu_table$(flavour)_L$(taxindex).txt otu_table_summarized_$(taxname)$(flavour).txt\n\n");
				} else {
					makerules.append(@"otu_table_summarized_$(taxname)$(flavour).txt: otu_table$(flavour).txt\n\t$$(QIIME_PREFIX)summarize_taxa.py -i otu_table$(flavour).txt -L $(taxindex) -o otu_table_summarized_$(taxname)$(flavour).txt -a\n\n");
				}
			}
		}

		/**
		 * Add a file to the targets to be built by make.
		 */
		public void add_target(string file) {
			targets.append_printf(" %s", file);
		}

		/**
		 * Add a file to the list of sources needed to build seq.fasta.
		 */
		public void add_sequence_source(string file) {
			seqsources.append_printf(" %s", file);
		}

		/**
		 * Add a rule to the Makefile.
		 *
		 * In reality, this allows you to append arbitrary content to the innards of the makefile. Obviously, you must output valid make rules and definitions which do not conflict with other definitions.
		 */
		[PrintfFormat]
		public void add_rule(string format, ...) {
			var va = va_list();
			makerules.append_vprintf(format, va);
		}

		/**
		 * Add declaration to the make Makefile.
		 */
		public new void set(string key, string value) {
			makerules.append_printf("%s = %s\n\n", key, value);
		}

		/**
		 * Register an XML “sample” element containing attributes satisfying the metadata requirements of the “defs”.
		 *
		 * @return the unique identifier for a sample. This must be associated with the map used in {@link prepare_sequences}.
		 */
		internal Sample add_sample(string tag, Xml.Node *sample) {
			var sample_obj = new Sample();
			sample_obj.limit = -1;
			sample_obj.xml = sample;
			sample_obj.id = samples.size;
			sample_obj.tag = tag;
			samples.add(sample_obj);
			return sample_obj;
		}

		/**
		 * Create a rule to extract sequence data from a command.
		 *
		 * It is assumed the supplied command will output FASTA data. The FASTA sequences will be binned into samples and the error output will be saved to a file.
		 * @param prep the command to prepare the sequence
		 */
		internal void prepare_sequences(string prep, Collection<Sample> samples) {
			var awkprint = new StringBuilder();
			foreach (var sample in samples) {
				awkprint.append_printf("if (name ~ /%s/", sample.tag);
				if (sample.limit > 0) {
					awkprint.append_printf(" && count%d < %d", sample.id, sample.limit);
				}
				awkprint.append_printf(") { print \">%d_\" NR \"\\n\" seq; count%d++; }", sample.id, sample.id);
			}
			seqrule.append_printf("\t(%s | awk '/^>/ { if (seq) {%s } name = substr($$0, 2); seq = \"\"; } $$0 !~ /^>/ {seq = seq $$0; } END { if (seq) {%s }}' >> seq.fasta) 2>&1 | bzip2 > seq_%d.log.bz2\n\n", prep, awkprint.str, awkprint.str, sequence_preparations++);
		}
		/**
		 * Include and process another parsed XML document.
		 */
		public void add_doc(Xml.Doc* doc) {
			doc_list.add(doc);
		}
		~Output() {
			foreach(var doc in doc_list) {
				delete doc;
			}
		}
	}

	/**
	 * Complain about something in an XML tag with some context for the user.
	 */
	[PrintfFormat]
	public void definition_error(Xml.Node *node, string format, ...) {
		var va = va_list();
		stderr.printf("%s: %d: ", node-> doc-> url, node-> line);
		stderr.vprintf(format, va);
	}

	/**
	 * Determine how compressed files are processed.
	 */
	public enum FileCompression {
		PLAIN,
		GZIP,
		BZIP;

		/**
		 * Get the tool that one would use to render the file to plain text.
		 */
		public string get_cat() {
			switch (this) {
			case FileCompression.GZIP :
				return "gunzip -c";
			case FileCompression.BZIP :
				return "bzcat";
			default :
				return "cat";
			}
		}

		/**
		 * Use magic to determine the compression format of the supplied file.
		 */
		public static FileCompression for_file(string file) {
			var magic = new LibMagic.Magic(LibMagic.Flags.SYMLINK|LibMagic.Flags.MIME_TYPE);
			magic.load();

			var mime = magic.file(file);
			if (mime == null) {
				return PLAIN;
			} else if (mime.has_prefix("application/x-bzip2")) {
				return BZIP;
			} else if (mime.has_prefix("application/x-gzip")) {
				return GZIP;
			} else {
				return PLAIN;
			}
		}
	}

	/**
	 * Class to provide access to {@link RuleProcessor}s in the correct parsing order.
	 */
	class RuleLookup : TypeModule {
		RuleType state;
		HashMap<string, RuleProcessor> table;
		HashSet<string> seen;
		public RuleLookup() {
			state = RuleType.DEFINITON;
			table = new HashMap<string, RuleProcessor>();
			seen = new HashSet<string>();
		}

		/**
		 * Write the list of files the processors need to be included to the Makefile.
		 */
		public void print_include(FileStream stream) {
			foreach (var rule in table.values) {
				var file = rule.get_include();
				if (file != null) {
					stream.printf("include %s\n", file);
				}
			}
		}

		/**
		 * Get the appropriate processor and update state so that the file is ensured to be in the correct order.
		 */
		public new RuleProcessor ? @get(string name) {
			if (!table.has_key(name)) {
				return null;
			}
			if (name in seen) {
				return null;
			}
			var processor = table[name];
			var type = processor.get_ruletype();
			if (type < state) {
				return null;
			}
			if (processor.is_only_once()) {
				seen.add(name);
			}
			state = type;
			return processor;
		}

		/**
		 * Register a new file processor.
		 */
		public void add(RuleProcessor processor) {
			var name = processor.get_name();
			table[name] = processor;
		}

		/**
		 * Register all rule processors in a type heirarchy. This assumes the can be instantiated with an empty constructor.
		 */
		public void add_children(Type t) requires (t.is_a(typeof(RuleProcessor))) {
			foreach (var child in t.children()) {
				if (child.is_instantiatable() && !child.is_abstract()) {
					add((RuleProcessor) Object.new(child));
				}
				add_children(child);
			}
		}

		/**
		 * Discover dynamically loadable modules/plugins.
		 */
		public void find_modules() {
			if (!Module.supported())
				return;
			var dir = File.new_for_path(MODDIR);
			if (dir == null)
				return;
			try {
				FileInfo? info = dir.query_info(FILE_ATTRIBUTE_STANDARD_TYPE, FileQueryInfoFlags.NONE, null);
				if (info == null || info.get_file_type() != FileType.DIRECTORY)
					return;
				var it = dir.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
				while((info = it.next_file()) != null) {
					var file = dir.get_child(info.get_name());

					if (info.get_file_type() == FileType.DIRECTORY)
						continue;
					if (ContentType.get_mime_type(info.get_content_type()) == "application/x-sharedlib") {
						var file_path = Path.build_filename(file.get_path(), info.get_name());
						var module = Module.open (file_path, ModuleFlags.BIND_LOCAL);
						if (module != null) {
							void* function;
							if (module.symbol("init", out function) && function != null) {
								var init_func = (InitFunc) function;
								module.make_resident();
								init_func(this);
							}
						}
					}
				}
			} catch (GLib.Error error) {
				if (!(error is IOError.NOT_FOUND)) {
					warning("Failed to discover modules in %s. %s", MODDIR, error.message);
				}
				return;
			}
		}
	}

	[CCode(has_target = false)]
	delegate void InitFunc(TypeModule module);

	/**
	 * Processor for definitions (aka “def” tags) in the input file.
	 */
	class Definition : RuleProcessor {
		public override RuleType get_ruletype() {
			return RuleType.DEFINITON;
		}
		public override unowned string get_name() {
			return "def";
		}
		public override unowned string ? get_include() {
			return null;
		}
		public override bool is_only_once() {
			return false;
		}
		public override bool process(Xml.Node *definition, Output output) {
			var name = definition-> get_prop("name");
			if (name == null) {
				definition_error(definition, "Definition missing name.\n");
				return false;
			}
			if (name == "regex" || name == "tag" || name == "limit") {
				definition_error(definition, "Reserved name used for definition.\n");
				return false;
			}
			if (output.vars.has_key(name)) {
				definition_error(definition, "Duplicate definition of %s.\n", name);
				return false;
			}
			var type = definition-> get_prop("type");
			if (type == null) {
				output.vars[name] = "s";
			} else if (VariantType.string_is_valid(type)) {
				output.vars[name] = type;
			} else {
				definition_error(definition, "Invalid type %s for %s.\n", type, name);
				return false;
			}
			return true;
		}
	}

	/**
	 * POSIX realpath function to caonicalise a path. Sadly, this is not in GLib anywhere.
	 */
	[CCode(cname = "realpath", cheader_filename = "stdlib.h")]
	extern string realpath(string path, [CCode(array_length = false, null_terminated = true)] char[] ? buffer = null);

	const string QIIME_VERSION_MARKER = "QIIME library version:\t";

	/**
	 * Check that we have a new enough release of QIIME on this system.
	 */
	public bool is_version_at_least(int major, int minor) {
		if (qiime_version.length > 0 && qiime_version[0] > major)
			return true;
		if (qiime_version.length > 1 && qiime_version[0] == major && qiime_version[1] >= minor)
			return true;
		return false;
	}

	int[] qiime_version;

	/**
	 * Determine the QIIME version
	 */
	int[]? get_qiime_version() {
		string output;
		string error;
		int status;
		
		// Get QIIME_PREFIX, and if it is NULL, set to empty string
		var qiime_config = (Environment.get_variable("QIIME_PREFIX")??"") + "print_qiime_config.py";
		
		try {
			if (!Process.spawn_command_line_sync(qiime_config, out output, out error, out status) || status != 0) {
				stderr.printf("Could not run \"%s\". The error output was:\n%s\n", qiime_config, error);
				return null;
			}
		} catch (SpawnError e) {
				stderr.printf("Could not run \"%s\": %s\n", qiime_config, e.message);
				return null;
		}
		var index = output.index_of(QIIME_VERSION_MARKER);
		if (index == -1) {
			stderr.printf("\"%s\" doesn't have a version string like I expect.\n", qiime_config);
			return null;
		}
		index += QIIME_VERSION_MARKER.length;
		int[] parts = {};
		int current = -1;
		while(index < output.length && output[index] != '\n') {
			if(output[index].isdigit()) {
				if (current == -1) {
					current = (int) (output[index] - '0');
				} else {
					current = current * 10 + (int) (output[index] - '0');
				}
			} else if (output[index] == '.') {
				parts += current;
				current = -1;
			}
			index++;
		}
		if (current != -1) {
			parts += current;
		}
		if (parts.length == 0) {
			stderr.printf("Could not make sense of the version from \"%s\".\n", qiime_config);
			return null;
		}
		stdout.printf("QIIME version: ");
		for (int i = 0; i < parts.length; i++) {
			if (i > 0)
				stdout.putc('.');
			stdout.printf("%d", parts[i]);
		}
		stdout.putc('\n');
		return parts;
	}

	bool process_document(string filename, RuleLookup lookup, Output output) {
		Xml.Doc *doc = Parser.parse_file(filename);
		if (doc == null) {
			stderr.printf("%s: unable to read or parse file\n", filename);
			return false;
		}

		Xml.Node *root = doc-> get_root_element();
		if (root == null) {
			stderr.printf("%s: no data in file\n", filename);
			return false;
			delete doc;
		}

		var version = root->get_prop("version");
		if (version == null) {
			stderr.printf("%s: has no version. I'll assume it's meant for this version.\n", filename);
		} else if (double.parse(version) > double.parse(VERSION)) {
			stderr.printf("%s: has a version newer than this version of AutoQIIME. I take no responsibility for any errors.\n", filename);
		}

		/* Iterate over the XML document and call all the appropriate rules. */
		for (Xml.Node *iter = root-> children; iter != null; iter = iter-> next) {
			if (iter-> type != ElementType.ELEMENT_NODE) {
				continue;
			}
			if (iter-> name == "include") {
				if (process_document(iter-> get_content(), lookup, output)) {
					continue;
				} else {
					stderr.printf("%s: %d: Problem in included file \"%s\".\n", filename, iter-> line, iter-> get_content());
					delete doc;
					return false;
				}
			}

			var rule = lookup[iter-> name];
			if (rule == null) {
				stderr.printf("%s: %d: The directive \"%s\" is either unknown, in the wrong place, or duplicated.\n", filename, iter-> line, iter-> name);
				delete doc;
				return false;
			}
			if (!rule.process(iter, output)) {
				stderr.printf("%s: %d: The directive \"%s\" is malformed.\n", filename, iter-> line, iter-> name);
				delete doc;
				return false;
			}
		}
		output.add_doc(doc);
		return true;
	}

	[CCode(cname = "register_plugin_types")]
	extern void register_plugin_types();

	int main(string[] args) {
		if (args.length != 2) {
			stderr.printf("Usage: %s config.aq\n", args[0]);
			return 1;
		}

		var version = get_qiime_version();
		if (version == null) {
			return 1;
		}
		qiime_version = version;

		var dirname = (args[1].has_suffix(".aq") ? args[1].substring(0, args[1].length-3) : args[1]).concat(".qiime");
		var output = new Output(dirname, args[1]);

		stdout.printf("Creating directory...\n");
		if (DirUtils.create_with_parents(dirname, 0755) == -1) {
			stderr.printf("%s: %s\n", dirname, strerror(errno));
			return 1;
		}

		/* Discover all the RuleProcessors in the plugin directory. This is really ugly. GLib doesn't know about a type until we register it by instantiating or calling typeof on it or one of it subtypes. There is some grep nastiness in the Makefile that goes and populates plugins/types.c with all the types it can find, so we can reflectively find them now. */
		register_plugin_types();
		/* Build a lookup for all the rules we know about. */
		var lookup = new RuleLookup();
		lookup.add(new Definition());
		lookup.add_children(typeof(RuleProcessor));
		lookup.find_modules();

		primers = new HashMap<string, string>();
		var primerfile = FileStream.open(Path.build_filename(DATADIR, "primers.lst"), "r");
		if (primerfile != null) {
			string line;
			while ((line = primerfile.read_line()) != null) {
				var parts = line.up().split("\t");
				if (parts.length != 2 || !is_sequence(parts[1])) {
					continue;
				}
				primers[parts[0]] = parts[1];
			}
		} else {
			stderr.printf("Warning: Couldn't find the primers list in \"%s\".\n", DATADIR);
		}

		if (!process_document(args[1], lookup, output)) {
			return 1;
		}

		/* Generate the Makefile and mapping.txt. */
		stdout.printf("Generating mapping file...\n");
		var state = output.generate_mapping();
		if (state) {
			stdout.printf("Generating makefile...\n");
			state = output.generate_makefile(lookup);
		}
		return state ? 0 : 1;
	}
}
