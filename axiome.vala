using Gee;
using Xml;

namespace AXIOME {

	HashMap<string, string> primers;
	[CCode(cname = "DATADIR")]
	extern const string DATADIR;
	[CCode(cname = "MODDIR")]
	extern const string MODDIR;
	[CCode(cname = "BINDIR")]
	extern const string BINDIR;

	/**
	 * Create a path for a file inside the bin directory where AXIOME was installed.
	 *
	 * e.g., bin_dir("aq-nmf") = "/usr/local/bin/aq-nmf"
	 */
	public string bin_dir(string filename) {
		return Path.build_filename(BINDIR, filename);
	}

	/**
	 * Create a path for a file inside the shared directory where AXIOME was installed.
	 *
	 * e.g., data_dir("nmf.R") = "/usr/local/share/axiome/nmf.R"
	 */
	public string data_dir(string filename) {
		return Path.build_filename(DATADIR, filename);
	}

	/**
	 * Checks if a file name contains things that will upset Make.
	 */
	public bool is_valid_filename(string filename) {
		return Regex.match_simple("^[A-Za-z0-9/_.:+=%~@{}\\[\\]-]+$", filename);
	}

	/**
	 * Structure for describing versions of AXIOME
	 */
	public struct version {
		int major;
		int minor;
		public version(int major, int minor) {
			this.major = major;
			this.minor = minor;
		}
		internal static bool parse(string str, out version result) {
			result = version(0, 0);
			var parts = str.split(".");
			if (parts.length != 2) {
				return false;
			}
			var major = int.parse(parts[0]);
			var minor = int.parse(parts[1]);
			if (major < 0 || minor < 0) {
				return false;
			}
			result = version(major, minor);
			return true;
		}
		internal bool older_than(version other) {
			return this.major < other.major || this.major == other.major && this.minor < other.minor;
		}
		public string to_string() {
			return @"$(major).$(minor)";
		}
		internal void update(version other) {
			if (this.older_than(other)) {
				this.major = other.major;
				this.minor = other.minor;
			}
		}
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
		 * Primers may be either a length, a name, or a string of nucleotides. Names are resolved using AXIOME's primer database. If a primer name begins with a #, the length of the named primer will be returned, instead of the primer itself.
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
		 * What version of AXIOME was this feature introduced in?
		 */
		public abstract version introduced_version();
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
	 * Pipeline options
	 */

	public enum Pipelines {
		QIIME = 1,
		MOTHUR = 2;

		public static Pipelines ? parse(string name) {
			var enum_class = (EnumClass) typeof(Pipelines).class_ref();
			var nick = name.down().replace("_", "-");
			unowned GLib.EnumValue ? enum_value = enum_class.get_value_by_nick(nick);
			if (enum_value != null) {
				Pipelines value = (Pipelines) enum_value.value;
				return value;
			}
			return null;
		}
		public string to_string() {
			return ((EnumClass) typeof (Pipelines).class_ref()).get_value(this).value_nick;
		}
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

	enum AlignMethod {
		INFERNAL,
		MUSCLE,
		PYNAST;

		internal static AlignMethod? parse(string method) {

				switch (method.down()) {
					case "infernal":
						return INFERNAL;
					case "muscle":
						return MUSCLE;
					case "pynast":
						return PYNAST;
					default:
						return null;
			}
		}

		internal void print(FileStream makefile) {
			switch (this) {
				case AlignMethod.INFERNAL:
					makefile.printf("ALIGN_METHOD = infernal\n");
					break;
				case AlignMethod.MUSCLE:
					makefile.printf("ALIGN_METHOD = muscle\n");
					break;
				case AlignMethod.PYNAST:
					makefile.printf("ALIGN_METHOD = pynast\n");
					break;
			}
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
		internal Pipelines pipeline;
		internal string? classification_method;
		internal string? otu_method;
		internal string? otu_refseqs;
		internal string? otu_blastdb;
		internal string? otu_chimera_refseqs;
		internal string? phylo_method;
		internal string? clust_ident;
		internal string? dist_cutoff;
		internal string? otu_flags;
		internal string? alignment_template;
		internal string? class_taxa;
		internal string? class_seqs;
		internal AlignMethod alignmethod;
		/**
		 * The defined variables and their types.
		 *
		 * (i.e., all the def tags)
		 */
		public HashMap<string, string> vars { get; private set; }
		Set<string> pcoa;
		Set<int> rareified;
		Set<string> summarized_otus;
		StringBuilder targets = new StringBuilder();
		ArrayList<Xml.Doc*> doc_list;
		internal bool verbose;

		internal Output(string dirname, string sourcefile) {
			this.dirname = dirname;
			this.sourcefile = realpath(sourcefile);

			sequence_preparations = 0;
			makerules = new StringBuilder();
			samples = new ArrayList<Sample>();
			seqrule = new StringBuilder();
			seqrule.printf("\t@echo Building sequence set...\n\t@test -d logs || mkdir logs\n\t@test ! -f seq.fasta || rm seq.fasta\n\t@test ! -f seq.group || rm seq.group\n");
			seqsources = new StringBuilder();
			pcoa = new HashSet<string>();
			rareified = new HashSet<int>();
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
			extra.append("\tFile\tLine\n");
			headers.append_c('\n');
			var result = true;
			foreach (var sample in samples) {
				mapping.append_printf("%d", sample.id);
				extra.append_printf("%d", sample.id);
				foreach (var entry in vars.entries) {
					var prop = sample.xml-> get_prop(entry.key);
					if (prop == null) {
						stderr.printf("%s: %d: Missing attribute %s.\n", sample.xml-> doc-> url, sample.xml-> line, entry.key);
						(entry.key == "Colour" || entry.key == "Description" ? extra : mapping).append_printf("\t");
						result = false;
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
				extra.append_printf("\t%s\t%d\n", sample.xml->doc->url, sample.xml->line);
			}
			return update_if_different("mapping.txt", mapping.str) && update_if_different("mapping.extra", extra.str) && update_if_different("headers.txt", headers.str) && result;
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

			makefile.printf("# Generated by %s from %s on %s\n# Modify at your own peril!\n# Built for QIIME ", PACKAGE, sourcefile, now.to_string());
			makefile.printf("%d", qiime_version[0]);
			for(var it = 1; it < qiime_version.length; it++) {
				makefile.printf(".%d", qiime_version[it]);
			}
			switch ( pipeline.to_string() ) {
				case "qiime":
					makefile.printf("\n\nPIPELINE = QIIME\n");
					break;
				case "mothur":
					makefile.printf("\n\nPIPELINE = MOTHUR\n");
					break;
				default:
					makefile.printf("\n\nPIPELINE = QIIME\n");
					break;
			}
			//Declare a variable that has our version number in it for Make to use
			if ( is_version_at_least(1,5) ) {
				makefile.printf("\nQIIME_GREATER_THAN_1_5 = TRUE");
			}
			if ( is_version_at_least(1,6) ) {
				makefile.printf("\nQIIME_GREATER_THAN_1_6 = TRUE");
			}
			if ( is_version_at_least(1,8) ) {
				makefile.printf("\nQIIME_1_8 = TRUE");
			}
			makefile.printf("\n\nall: Makefile mapping.txt otu_table.txt %s\n\n", targets.str);
			makefile.printf("Makefile mapping.txt: %s\n\t@echo Updating analyses to be run...\n\t$(V)axiome $<\n\n", sourcefile);
			if (classification_method != null) {
				makefile.printf("CLASSIFICATION_METHOD = %s\n", classification_method);
			}
			if (otu_method != null) {
				makefile.printf("OTU_PICKING_METHOD = %s\n", otu_method);
			}
			if (otu_refseqs != null) {
				makefile.printf("OTU_REFSEQS = %s\n", otu_refseqs);
			}
			if (otu_blastdb != null) {
				makefile.printf("OTU_BLASTDB = %s\n", otu_blastdb);
			}
			if (otu_chimera_refseqs != null) {
				makefile.printf("OTU_CHIMERA_REFSEQS = %s\n", otu_chimera_refseqs);
			}
			if (phylo_method != null) {
				makefile.printf("PHYLO_METHOD = %s\n", phylo_method);
			}
			if (clust_ident != null) {
				makefile.printf("CLUSTER_IDENT = %s\n", clust_ident);
			}
			if (dist_cutoff != null) {
				makefile.printf("DIST_CUTOFF = %s\n", dist_cutoff);
			}
			if (otu_flags != null) {
				makefile.printf("OTU_FLAGS = %s\n", otu_flags);
			}
			if (alignment_template != null) {
				makefile.printf("ALIGNMENT_TEMPLATE = %s\n", alignment_template);
			}
			if (class_taxa != null) {
				makefile.printf("CLASS_TAXA = %s\n", class_taxa);
			}
			if (class_seqs != null) {
				makefile.printf("CLASS_SEQS = %s\n", class_seqs);
			}
			if (verbose) {
				makefile.printf("V = \n");
			}
			alignmethod.print(makefile);
			makefile.printf("SEQSOURCES =%s\n\nseq.fasta seq.group: $(SEQSOURCES)\n%s", seqsources.str, seqrule.str);
			//Print out the stats for the sample file
			makefile.printf("\t$(V)awk '{ if (NR == 1) { print \"Sample\\tBarcode\\tSequences Contributed\\n\" } if (min == \"\") { min = max = $$3 }; if ( $$3 > max ) { max = $$3 }; if ( $$3 < min ) { min = $$3 }; total += $$3; count += 1; print; } END { print \"\\nAverage Sequences Contributed: \" total/count \"\\nSmallest Sequences Contributed: \" min \"\\nLargest Sequences Contributed: \" max }' sample_reads_temp.log > sample_reads.log\n\n");
			makefile.printf("\t$(V)rm sample_reads_temp.log\n\n");
			makefile.printf("%s.PHONY: all\n\ninclude %s/aq-base\n", makerules.str, BINDIR);
			makefile.printf("include %s/aq-qiime-base\n", BINDIR);
			makefile.printf("include %s/aq-mothur-base\n", BINDIR);
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
					makerules.append(@"otu_table_summarized_$(taxname)$(flavour).txt: otu_table$(flavour).txt\n\t@echo Summarizing OTU table $(flavour) to $(taxname)-level...\n\t$$(V)$$(QIIME_PREFIX)summarize_taxa.py -i otu_table$(flavour).txt -L $(taxindex) -o . -a\n\t@mv otu_table$(flavour)_L$(taxindex).txt otu_table_summarized_$(taxname)$(flavour).txt\n\n");
				} else {
					makerules.append(@"otu_table_summarized_$(taxname)$(flavour).txt: otu_table$(flavour).txt\n\t@echo Summarizing OTU table $(flavour) to $(taxname)-level...\n\t$$(V)$$(QIIME_PREFIX)summarize_taxa.py -i otu_table$(flavour).txt -L $(taxindex) -o otu_table_summarized_$(taxname)$(flavour).txt -a\n\n");
				}
			}
		}

		/**
		 * Generate rareified OTU tables
		 */
		public void make_rarefied(int size) {
			if (size in rareified) {
				return;
			}
			rareified.add(size);
			makerules.append(@"otu_table_$(size).txt: otu_table.txt\n\tRareifying OTU table to $(size) sequences...\n\t$$(V)$$(QIIME_PREFIX)single_rarefaction.py -i otu_table.txt -o otu_table_auto.txt -d $(size) $(is_version_at_least(1, 3) ? "" : "--lineages_included")\n\n");
		}

		/**
		 * Generate beta-diversity (Unifrac PCOA) analysis
		 *
		 * This assumes the OTU has already been generated.
		 */
		public void make_pcoa(string flavour) {
			if (flavour in pcoa) {
				return;
			}
			pcoa.add(flavour);
			makerules.append(@"beta_div$(flavour)/unweighted_unifrac_otu_table$(flavour).txt beta_div$(flavour)/weighted_unifrac_otu_table$(flavour).txt: otu_table$(flavour).txt seq.fasta_rep_set_aligned_pfiltered.tre\n\t@echo Doing beta diversity analysis $(flavour)...\nifdef MULTICOREBROKEN\n\t$$(V)$$(QIIME_PREFIX)parallel_beta_diversity.py -i otu_table$(flavour).txt -m weighted_unifrac,unweighted_unifrac -o beta_div$(flavour) -t seq.fasta_rep_set_aligned_pfiltered.tre -O $$(NUM_CORES)\nelse\n\t$$(V)$$(QIIME_PREFIX)beta_diversity.py -i otu_table$(flavour).txt -m weighted_unifrac,unweighted_unifrac -o beta_div$(flavour) -t seq.fasta_rep_set_aligned_pfiltered.tre\nendif\n\n");
			makerules.append(@"beta_div_pcoa$(flavour)/pcoa_unweighted_unifrac_otu_table$(flavour).txt beta_div_pcoa$(flavour)/pcoa_weighted_unifrac_otu_table$(flavour).txt: beta_div$(flavour)/unweighted_unifrac_otu_table$(flavour).txt beta_div$(flavour)/weighted_unifrac_otu_table$(flavour).txt\n\t@echo Computing principal coordinates $(flavour)...\n\t$$(V)$$(QIIME_PREFIX)principal_coordinates.py -i beta_div$(flavour) -o beta_div_pcoa$(flavour)\n\n");
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
		public void add_rule(string str) {
			makerules.append(str);
		}

		/**
		 * Add a rule to the Makefile.
		 *
		 * In reality, this allows you to append arbitrary content to the innards of the makefile. Obviously, you must output valid make rules and definitions which do not conflict with other definitions.
		 */
		[PrintfFormat]
		public void add_rulef(string format, ...) {
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
			var awkcheck = new StringBuilder();
			foreach (var sample in samples) {
				if (sample.tag != "*") {
					awkprint.append_printf(" if (name ~ /%s/", sample.tag);
				} else {
					//Hacky approach to not doing a filter when sample tag is *
					awkprint.append_printf(" if ( 1");
				}
				if (sample.limit > 0) {
					awkprint.append_printf(" && count%d < %d", sample.id, sample.limit);
				}
				awkprint.append_printf(") { print \">%d_\" NR \"\\n\" seq; print \"%d_\" NR \"\\t%d\" >> \"seq.group\"; count%d++; }", sample.id, sample.id, sample.id, sample.id);
				awkcheck.append_printf(" if (count%d == 0) { print \"Library defined in %s:%d contributed no sequences. This is probably not what you want.\" > \"/dev/stderr\"; print \"%d\\tWarning: %s contributed no sequences to library\" >> \"sample_reads_temp.log\" } else { ", sample.id, sample.xml-> doc-> url, sample.xml-> line, sample.id, sample.tag);
				awkcheck.append_printf("print \"%d\\t%s\\t\" count%d >> \"sample_reads_temp.log\" }", sample.id, sample.tag, sample.id);
			}
			seqrule.append_printf("\t$(V)(%s | awk '/^>/ { if (seq) {%s } name = substr($$0, 2); seq = \"\"; } $$0 !~ /^>/ { seq = seq $$0; } END { if (seq) {%s }%s }' >> seq.fasta) 2>&1 | bzip2 > logs/seq_%d.log.bz2\n\n", prep, awkprint.str, awkprint.str, awkcheck.str, sequence_preparations++);
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
					assert(is_valid_filename(file));
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
		public override version introduced_version() {
			return version(1, 0);
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

	bool process_document(string filename, RuleLookup lookup, Output output, bool is_root = false) {
		var absfilename = realpath(filename);
		if (absfilename == null) {
			stderr.printf("%s: Cannot canonicalize path.\n", filename);
			return false;
		}

		Xml.Doc *doc = Parser.parse_file(absfilename);
		if (doc == null) {
			stderr.printf("%s: unable to read or parse file\n", filename);
			return false;
		}

		Xml.Node *root = doc-> get_root_element();
		if (root == null) {
			stderr.printf("%s: no data in file\n", filename);
			return false;
		}

		var version_str = root->get_prop("version");
		if (version_str == null) {
			stderr.printf("%s: the version of AXIOME required is not specified. If in doubt, try <axiome version=\"%s\">.\n", filename, axiome_version.to_string());
			delete doc;
			return false;
		}

		version file_version;
		if (!version.parse(version_str, out file_version)) {
			stderr.printf("%s: Unrecognizable version. Should be X.Y, but is %s", filename, version_str);
			delete doc;
			return false;
		}
		if (axiome_version.older_than(file_version)) {
			stderr.printf("%s: requires a version newer (%s) than this version of AXIOME (%s).\n", filename, file_version.to_string(), axiome_version.to_string());
			delete doc;
			return false;
		}
		var max_version = version(0, 0);

		if (root-> name != "axiome" && root-> name != "autoqiime") {
			stderr.printf("%s: the included file's root element is \"%s\" rather than \"axiome\". Are you sure this is an AXIOME file?\n", filename, root-> name);
			delete doc;
			return false;
		} else if (root-> name == "autoqiime" && version(1, 5).older_than(file_version)) {
			stderr.printf("%s: this file's root element is \"autoqiime\" and that shouldn't be done any more.\n", filename);
		}

		if (is_root) {
			//Define our pipeline. Default to QIIME if not provided.
			var pipeline = root->get_prop("pipeline");
			if (pipeline == null) {
				output.pipeline = Pipelines.parse("qiime");
			} else {
				var parsedPipe = Pipelines.parse(pipeline);
				if (parsedPipe == null) {
					stderr.printf("%s: Unrecognized pipeline option \"%s\". Valid options are qiime, mothur.\n", filename, pipeline);
					delete doc;
					return false;
				} else {
					output.pipeline = parsedPipe;
				}
			}

			//This is only used by QIIME pipeline at the moment.
			var phylo_method = root->get_prop("phylogeny-method");
			if (output.pipeline.to_string() == "qiime") {
				if (phylo_method != null) {
					switch (phylo_method.down()) {
						case "raw-fasttreemp":
						case "raw-fasttree-mp":
						case "rawfasttreemp":
							output.phylo_method = "raw-fasttreemp";
							break;
						case "raw-fasttree":
						case "rawfasttree":
							output.phylo_method = "raw-fasttree";
							break;
						case "fasttree":
						case "fast-tree":
							output.phylo_method = "fasttree";
							break;
						case "clearcut":
						case "clear-cut":
							output.phylo_method = "clearcut";
							break;
						case "clustalw":
						case "clustal":
						case "clust":
							output.phylo_method = "clustalw";
							break;
						case "fasttree_v1":
						case "fasttreev1":
						case "fast-tree_v1":
						case "fast-treev1":
							output.phylo_method = "fasttree_v1";
							break;
						case "raxml":
						case "rax":
							output.phylo_method = "raxml";
							break;
						case "raxml_v730":
						case "raxml730":
							output.phylo_method = "raxml_v730";
							break;
						case "muscle":
							output.phylo_method = "muscle";
							break;
						default:
							stderr.printf("%s: Unknown Phylogeny method \"%s\".\n", filename, phylo_method);
							delete doc;
							return false;
					}
				}
			} else {
				if (phylo_method != null) {
					stderr.printf("%s: phylo-method parameter is not compatible with mothur pipeline. Please remove.\n", filename);
					delete doc;
					return false;
				}
			}

			//Clustering identity. QIIME uses similarity, ie 0.97 for species level
			//mothur uses distance, ie 0.03 for species level
			var clust_ident = root->get_prop("cluster-identity");
			if (clust_ident != null) {
				double ident_val = double.parse(clust_ident);
				if (ident_val > 1 || ident_val <= 0) {
					stderr.printf("%s: Clustering identity must be between 0 and 1. Identity given: \"%s\".\n", filename, clust_ident);
					delete doc;
					return false;
				}
				if (output.pipeline.to_string() == "qiime") {
					output.clust_ident = clust_ident;
				} else {
					//mothur uses distance, not similarity
					double dist_val = 1 - ident_val;
					double cutoff_val = dist_val + 0.05;
					clust_ident = dist_val.to_string();
					string dist_cutoff = cutoff_val.to_string();
					//Double conversion to string causes odd decimal place issues
					//If the value is larger than 4 characters, slice it down
					if (clust_ident.length > 4) {
						clust_ident = clust_ident.slice(0,4);
					}
					if (dist_cutoff.length > 4) {
						dist_cutoff = dist_cutoff.slice(0,4);
					}
					//Special case: mothur calls 0% distance "unique"
					if (ident_val == 0) {
						clust_ident = "unique";
					}
					output.dist_cutoff = dist_cutoff;
					output.clust_ident = clust_ident;
				}
			}

			var class_method = root->get_prop("classification-method");
			if (output.pipeline.to_string() == "mothur") {
				if (class_method != null) {
					stderr.printf("%s: classification-method only compatible with QIIME pipeline. Remove if using mothur.\n", filename);
					delete doc;
					return false;
				}
			} else if (output.pipeline.to_string() == "qiime") {
				if (class_method != null) {
					switch (class_method.down()) {
						case "blast":
							output.classification_method = "blast";
							break;
						case "rdp":
							output.classification_method = "rdp";
							break;
						case "rtax":
							output.classification_method = "rtax";
							break;
						default:
							stderr.printf("%s: Unknown classification method \"%s\".", filename, class_method);
							delete doc;
							return false;
					}
				} else {
					output.classification_method = "rdp";
				}
			}

			var method = root->get_prop("otu-method");
			if (output.pipeline.to_string() == "qiime") {
				if (method != null) {
					switch (method.down()) {
						case "cdhit":
						case "cd-hit":
							output.otu_method = "cdhit";
							break;
						case "uclust":
							output.otu_method = "uclust";
							break;
						case "raw-uclust":
						case "rawuclust":
							output.otu_method = "raw-uclust";
							break;
						case "raw-cdhit":
						case "rawcdhit":
						case "raw-cd-hit":
						case "rawcd-hit":
							output.otu_method = "raw-cdhit";
							break;
						case "uclust-ref":
						case "uclust_ref":
						case "uclustref":
							var uclustref = root->get_prop("otu-refseqs");
							if (uclustref == null) {
								stderr.printf("%s: otu-refseqs argument must be provided for uclust_ref OTU picking method.", filename);
								delete doc;
								return false;
							}
							output.otu_method = "uclust_ref";
							output.otu_refseqs = uclustref;
							break;
						case "usearch-ref":
						case "usearch_ref":
						case "usearchref":
							var usearchref = root->get_prop("otu-refseqs");
							if (usearchref == null) {
								stderr.printf("%s: otu-refseqs argument must be provided for usearch_ref OTU picking method.", filename);
								delete doc;
								return false;
							}
							output.otu_method = "usearch_ref";
							output.otu_refseqs = usearchref;
							break;
						case "blast":
							var blastref = root->get_prop("otu-refseqs");
							var blastdb = root->get_prop("otu-blastdb");
							if (blastref == null && blastdb == null) {
								stderr.printf("%s: otu-refseqs or otu-blastdb argument must be provided for BLAST OTU picking method.", filename);
								delete doc;
								return false;
							}
							if (blastref != null && blastdb != null) {
								stderr.printf("%s: Only one of otu-refseqs or otu-blastdb may be used for BLAST OTU picking method.", filename);
								delete doc;
								return false;
							}
							output.otu_method = "blast";
							output.otu_refseqs = blastref;
							output.otu_blastdb = blastdb;
							break;
						case "trie":
							output.otu_method = "trie";
							break;
						case "mothur":
						case "mother":
							output.otu_method = "mothur";
							break;
						case "prefix_suffix":
						case "prefix-suffix":
						case "prefixsuffix":
							output.otu_method = "prefix_suffix";
							break;
						case "usearch":
							output.otu_method = "usearch";
							output.otu_chimera_refseqs = root->get_prop("otu-refseqs");
							break;
						default:
							stderr.printf("%s: Unknown OTU picking method \"%s\".\n", filename, method);
							delete doc;
							return false;
					}
				} else {
						output.otu_method = "cdhit";
				}
				//Grab additional flags for QIIME
				output.otu_flags = root->get_prop("otu-flags");

			//mothur OTU options
			} else {
					if (method != null) {
						switch (method.down()) {
							case "an":
							case "average":
							case "average neighbor":
							case "averageneighbor":
								output.otu_method = "an";
								break;
							case "fn":
							case "furthest":
							case "furthest neighbor":
							case "furthestneighbor":
								output.otu_method = "fn";
								break;
							case "nn":
							case "nearest":
							case "nearest neighbor":
							case "nearestneighbor":
								output.otu_method = "nn";
								break;
							default:
								stderr.printf("%s: Unknown OTU picking method \"%s\".\n", filename, method);
								delete doc;
								return false;
							}
					} else {
						//mothur OTU default
						output.otu_method = "an";
					}
			}


			var alignmethod = root->get_prop("align-method");
			if (output.pipeline.to_string() == "qiime") {
				if (alignmethod != null) {
					var val = AlignMethod.parse(alignmethod);
					if (val == null) {
						stderr.printf("%s: Unknown alignment method \"%s\".\n", filename, alignmethod);
						delete doc;
						return false;
					}
					output.alignmethod = val;
				} else {
					// Set default to PYNAST
					output.alignmethod = AlignMethod.PYNAST;
				}
			} else {
				if (alignmethod != null) {
					stderr.printf("%s: align-method parameter is not compatible with mothur pipeline. Please remove.\n", filename);
					delete doc;
					return false;
				}
			}

			var alignment_template = root->get_prop("alignment-template");
			if (alignment_template != null) {
				var template_file = File.new_for_path(alignment_template);
					if (! template_file.query_exists()) {
						stderr.printf ("%s: Alignment template file \"%s\" doesn't exist.\n", filename, alignment_template);
						delete doc;
						return false;
					} else {
						output.alignment_template = alignment_template;
					}
			} else {
				//alignment template is required for mothur
				if (output.pipeline.to_string() == "mothur") {
					stderr.printf("%s: alignment-template parameter required for mothur pipeline.\n", filename);
					delete doc;
					return false;
				}
			}

			var class_taxa = root->get_prop("classification-taxa");
			var class_seqs = root->get_prop("classification-seqs");
			if (output.pipeline.to_string() == "mothur") {
				if (class_taxa == null || class_seqs == null) {
					stderr.printf("%s: classification-taxa and classification-seqs parameters are required for mothur pipeline.\n", filename);
					delete doc;
					return false;
				} else {
					var class_taxa_file = File.new_for_path(class_taxa);
					var class_seqs_file = File.new_for_path(class_seqs);
					if (! class_taxa_file.query_exists()) {
						stderr.printf("%s: Classification taxa file \"%s\" doesn't exist.\n", filename, class_taxa);
						delete doc;
						return false;
					} else if (! class_seqs_file.query_exists()) {
						stderr.printf("%s: Classifications seqs file \"%s\" doesn't exist.\n", filename, class_seqs);
						delete doc;
						return false;
					}
					output.class_taxa = class_taxa;
					output.class_seqs = class_seqs;
				}
			} else {
				if (class_taxa != null || class_seqs != null) {
						stderr.printf("%s: classification-taxa and classification-seqs parameters are only used with mothur pipeline. For QIIME pipeline, please see the rdp plugin.\n", filename);
						delete doc;
						return false;
				}
			}

			var verbose = root->get_prop("verbose");
			if (verbose != null) {
				switch (verbose.down()) {
					case "true":
					case "yes":
					case "verbose":
						output.verbose = true;
						break;
					case "false":
					case "no":
					case "quiet":
					case "silent":
						output.verbose = false;
						break;
					default:
						stderr.printf("%s: Unknown verbosity \"%s\".\n", filename, verbose);
						return false;
				}
			}
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
			var rule_version = rule.introduced_version();
			if (file_version.older_than(rule_version)) {
				stderr.printf("%s: %d: The directive \"%s\" is requires at least AXIOME %s but this file specifies that it only needs version %s.\n", filename, iter-> line, iter-> name, rule_version.to_string(), file_version.to_string());
				delete doc;
				return false;
			}
			max_version.update(rule_version);
			if (!rule.process(iter, output)) {
				stderr.printf("%s: %d: The directive \"%s\" is malformed.\n", filename, iter-> line, iter-> name);
				delete doc;
				return false;
			}
		}
		if (max_version.older_than(file_version)) {
			stderr.printf("%s: Warning: claims to require AXIOME %s, but it only uses features from %s.\n", filename, file_version.to_string(), max_version.to_string());
		}
		output.add_doc(doc);
		return true;
	}

	[CCode(cname = "register_plugin_types")]
	extern void register_plugin_types();

	version axiome_version;

	int main(string[] args) {
		assert(version.parse(VERSION, out axiome_version));
		if (args[0].has_suffix("autoqiime")) {
			stderr.printf("Please use axiome to invoke this command.\n");
		}
		if (args.length != 2) {
			stderr.printf("Usage: %s config.ax\n", args[0]);
			return 1;
		}

		var version = get_qiime_version();
		if (version == null) {
			version = {0,0,0};
		}
		qiime_version = version;
		var rootname = ( args[1].has_suffix(".aq") || args[1].has_suffix(".ax") ) ? args[1].substring(0, args[1].length-3) : args[1];
		var dirname = rootname.concat(FileUtils.test(rootname.concat(".qiime"), FileTest.IS_DIR) ? ".qiime" : ".axiome");
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

		var absfilename = realpath(args[1]);
		if (absfilename == null) {
			stderr.printf("%s: Cannot canonicalize path.\n", args[1]);
			return 1;
		}
		if (!is_valid_filename(absfilename)) {
			stderr.printf("%s: Filename might break Make. Please remove the weird characters in the path.\n", absfilename);
			return 1;
		}

		if (!process_document(absfilename, lookup, output, true)) {
			return 1;
		}

		if (output.known_samples.size == 0) {
			stderr.printf("There are no samples specified.\n");
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
