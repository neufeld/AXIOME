using GLib;
using Gee;
using RealPath;
using Xml;

namespace AutoQIIME {

	enum RuleType { DEFINITON, SOURCE, ANALYSIS }

	/**
	 * Rule processor interface for analyses and data sources
	 */
	abstract class RuleProcessor : Object {
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
	 * Source of sequence data
	 */
	namespace Sources {

		/**
		 * Copy data from existing FASTA files
		 */
		class FastaSource : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.SOURCE;
			}
			public override unowned string get_name() {
				return "fasta";
			}
			public override unowned string ? get_include() {
				return null;
			}
			public override bool is_only_once() {
				return false;
			}

			public override bool process(Xml.Node *node, Output output) {
				var file = node-> get_prop("file");
				if (file == null) {
					definition_error(node, "FASTA file not specified.\n");
					return false;
				}
				if (!FileUtils.test(file, FileTest.EXISTS)) {
					definition_error(node, "File `%s' does not exist.\n", file);
					return false;
				}
				var subst = new HashMap<string, int>();
				for (Xml.Node *sample = node-> children; sample != null; sample = sample-> next) {
					if (sample-> type != ElementType.ELEMENT_NODE) {
						continue;
					}
					var regexstr = sample-> get_prop("regex");
					if (sample-> name != "sample" || regexstr == null || regexstr == "") {
						definition_error(node, "Invalid element %s. Ignorning, mumble, mumble.\n", sample-> name);
						try {
							new Regex(regexstr);
						} catch(RegexError e) {
							definition_error(node, "Invalid regex %s. If you want everything, just make regex=\".\" or go read about the joy of POSIX regexs.\n", regexstr);
							return false;
						}
						continue;
					}
					if (regexstr in subst) {
						definition_error(node, "Duplicated regex `%s'. Skipping.\n", regexstr);
						continue;
					}
					subst[regexstr] = output.add_sample(sample);
				}

				output.add_sequence_source(file);
				var command = "%s %s".printf(FileCompression.for_file(file).get_cat(), Shell.quote(file));
				output.prepare_sequences(command, subst);
				return true;
			}
		}

		/**
		 * Assemble data using PANDAseq from Illumina files.
		 */
		class PandaSource : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.SOURCE;
			}
			public override unowned string get_name() {
				return "panda";
			}
			public override unowned string ? get_include() {
				return null;
			}
			public override bool is_only_once() {
				return false;
			}
			public override bool process(Xml.Node *definition, Output output) {

				var forward = definition-> get_prop("forward");
				if (forward == null) {
					definition_error(definition, "Forward file not specified.\n");
					return false;
				}
				if (!FileUtils.test(forward, FileTest.EXISTS)) {
					definition_error(definition, "File `%s' does not exist.\n", forward);
					return false;
				}

				var reverse = definition-> get_prop("reverse");
				if (reverse == null) {
					definition_error(definition, "Reverse file not specified.\n");
					return false;
				}
				if (!FileUtils.test(reverse, FileTest.EXISTS)) {
					definition_error(definition, "File does not exist.\n");
					return false;
				}

				bool dashj = false;
				bool dashsix;
				bool domagic;
				bool convert;

				var version = definition-> get_prop("version");
				if (version == null) {
					definition_error(definition, "No version specified. I'm going to assume you have the latest version.\n");
					domagic = true;
					convert = false;
					dashsix = false;
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
					definition_error(definition, "The version `%s' is not one that I recognise. You should probably do something about that. Until then, I'm going to make some assumptions.\n", version);
					domagic = true;
					convert = false;
					dashsix = false;
				}

				if (convert) {
					var oldforward = forward;
					var oldreverse = reverse;
					forward = "converted%x_1.fastq.bz2".printf(oldforward.hash());
					reverse = "converted%x_2.fastq.bz2".printf(oldreverse.hash());
					output.add_rule("%s: %s\n\tzcat %s | oldillumina2fastq > %s\n\n%s: %s\n\tzcat %s | oldillumina2fastq > %s\n\n", forward, oldforward, oldforward, forward, reverse, oldreverse, oldreverse, reverse);
					domagic = false;
					dashj = true;
				}

				if (domagic) {
					dashj = FileCompression.for_file(forward) == FileCompression.BZIP;
				}

				var subst = new HashMap<string, int>();
				for (Xml.Node *sample = definition-> children; sample != null; sample = sample-> next) {
					if (sample-> type != ElementType.ELEMENT_NODE) {
						continue;
					}
					var tag = sample-> get_prop("tag");
					if (sample-> name != "sample" || tag == null || tag == "") {
						definition_error(definition, "Invalid element %s. Ignorning, mumble, mumble.\n", sample-> name);
						continue;
					}
					if (tag in subst) {
						definition_error(definition, "Duplicated tag %s. Skipping.\n", tag);
						continue;
					}
					subst[tag] = output.add_sample(sample);
				}

				output.add_sequence_source(forward);
				output.add_sequence_source(reverse);
				var command = new StringBuilder();
				command.append_printf("\t(pandaseq -N -f %s -r %s", Shell.quote(forward), Shell.quote(reverse));

				if (dashj) {
					command.append_printf(" -j");
				}
				if (dashsix) {
					command.append_printf(" -6");
				}
				var fprimer = definition-> get_prop("fprimer");
				if (fprimer != null) {
					if (Regex.match_simple("^([ACGTacgt]*)|(\\d*)$", fprimer)) {
						command.append_printf(" -p %s", Shell.quote(fprimer));
					} else {
						definition_error(definition, "Invalid primer %s. Ignorning, mumble, mumble.\n", fprimer);
					}
				}
				var rprimer = definition-> get_prop("rprimer");
				if (rprimer != null) {
					if (Regex.match_simple("^([ACGTacgt]*)|(\\d*)$", rprimer)) {
						command.append_printf(" -q %s", Shell.quote(rprimer));
					} else {
						definition_error(definition, "Invalid primer %s. Ignorning, mumble, mumble.\n", rprimer);
					}
				}
				var threshold = definition-> get_prop("threshold");
				if (threshold != null) {
					command.append_printf(" -t %s", Shell.quote(threshold));
				}
				command.append_printf(" -C /usr/local/lib/pandaseq/validtag.so");
				foreach (var entry in subst.entries) {
					command.append_printf(":%s", entry.key);
				}
				output.prepare_sequences(command.str, subst);
				return true;
			}
		}
	}

	namespace Analyses {
		class QualityAnalysis : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.ANALYSIS;
			}
			public override unowned string get_name() {
				return "qualityanal";
			}
			public override unowned string ? get_include() {
				return "/Winnebago/apmasell/tools/bin-common/qualityanal";
			}
			public override bool is_only_once() {
				return true;
			}
			public override bool process(Xml.Node *definition, Output output) {
				output.add_target("qualityanal");
				output.add_rule("FASTQFILES = $(SEQSOURCES)\n\n");
				return true;
			}
		}
		class LibraryComparison : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.ANALYSIS;
			}
			public override unowned string get_name() {
				return "compare";
			}
			public override unowned string ? get_include() {
				return null;
			}
			public override bool is_only_once() {
				return true;
			}
			public override bool process(Xml.Node *definition, Output output) {
				var taxlevel = TaxonomicLevel.parse(definition-> get_prop("level"));
				if (taxlevel == null) {
					definition_error(definition, "Unknown taxonomic level \"%s\" in library abundance comparison analysis.\n", definition-> get_prop("level"));
					return false;
				}
				var taxname = taxlevel.to_string();
				output.make_summarized_otu(taxlevel, "");
				output.add_target("correlation_%s.pdf".printf(taxname));
				output.add_rule("correlation_%s.pdf: otu_table_summarized_%s.txt mapping.txt\n\tqiime_cmplibs %s\n\n", taxname, taxname, taxname);
				return true;
			}
		}

		class AlphaDiversity : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.ANALYSIS;
			}
			public override unowned string get_name() {
				return "alpha";
			}
			public override unowned string ? get_include() {
				return null;
			}
			public override bool is_only_once() {
				return true;
			}
			public override bool process(Xml.Node *definition, Output output) {
				output.add_target("alpha");
				return true;
			}
		}

		class BlastDatabase : RuleProcessor {
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
				output.add_rule("blast: Makefile\n\t@echo '#!/bin/sh' > blast\n\t@echo blastall -p blastp -d \\'%s/nr\\' '\"$$@\"' >> blast\n\tchmod a+x blast\n\n", Shell.quote(output.dirname));

				return true;
			}
		}

		class RankAbundance : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.ANALYSIS;
			}
			public override unowned string get_name() {
				return "rankabundance";
			}
			public override unowned string ? get_include() {
				return null;
			}
			public override bool is_only_once() {
				return true;
			}
			public override bool process(Xml.Node *definition, Output output) {
				output.add_target("rank_abundance/rank_abundance.pdf");
				return true;
			}
		}

		class BetaDiversity : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.ANALYSIS;
			}
			public override unowned string get_name() {
				return "beta";
			}
			public override unowned string ? get_include() {
				return null;
			}
			public override bool is_only_once() {
				return false;
			}
			public override bool process(Xml.Node *definition, Output output) {
				if (!output.vars.has_key("Colour") || output.vars["Colour"] != "s") {
					definition_error(definition, "Biplots require there to be a \"Colour\" associated with each sample.\n");
				}
				if (!output.vars.has_key("Description") || output.vars["Description"] != "s") {
					definition_error(definition, "Biplots require there to be a \"Description\" associated with each sample.\n");
					return true;
				}

				string flavour;
				var size = definition-> get_prop("size");
				if (size == null) {
					flavour = "";
				} else if (size == "auto") {
					flavour = "_auto";
				} else {
					int v = int.parse(size);
					if (v < 1) {
						definition_error(definition, "Cannot rareify to a size of `%s'. Use a positive number or `auto'.\n", size);
						return false;
					}
					flavour = "_%d".printf(v);
					output.add_rule("otu_table_%d.txt: otu_table.txt\n\tsingle_rarefaction.py -i otu_table.txt -o otu_table_auto.txt --lineages_included -d %d\n\n", v, v);
				}

				var taxlevel = TaxonomicLevel.parse(definition-> get_prop("level"));
				if (taxlevel == null) {
					definition_error(definition, "Unknown taxonomic level \"%s\" in beta diversity analysis.\n", definition-> get_prop("level"));
					return false;
				}
				var taxname = taxlevel.to_string();

				output.make_summarized_otu(taxlevel, flavour);
				output.add_rule("prefs_%s%s.txt: otu_table_summarized_%s%s.txt\n\tmake_prefs_file.py -i otu_table_summarized_%s%s.txt  -m mapping.txt -k white -o prefs_%s%s.txt\n\n", taxname, flavour, taxname, flavour, taxname, flavour, taxname, flavour);
				output.add_rule("biplot_coords_%s%s.txt: otu_table_summarized_%s%s.txt\n\tmake_3d_plots.py -t otu_table_summarized_%s%s.txt -i beta_div_pcoa%s/pcoa_weighted_unifrac_otu_table.txt -m mapping.txt -p prefs_%s%s.txt -o biplot%s%s --biplot_output_file biplot_coords_%s%s.txt\n\n", taxname, flavour, taxname, flavour, taxname, flavour, flavour, taxname, flavour, taxname, flavour, taxname, flavour);
				output.add_rule("biplot_%s%s.svg: biplot_coords_%s%s.txt\n\tbiplot %s%s\n\n", taxname, flavour, taxname, flavour, taxname, flavour);
				output.add_rule("bubblelot_%s%s.svg: biplot_coords_%s%s.txt\n\tbubbleplot %s%s\n\n", taxname, flavour, taxname, flavour, taxname, flavour);

				output.add_target("biplot_coords_%s%s.txt".printf(taxname, flavour));
				return true;
			}
		}
	}

	enum TaxonomicLevel { LIFE = 1, DOMAIN = 2, PHYLUM = 3, CLASS = 4, ORDER = 5, FAMILY = 6, GENUS = 7, SPECIES = 8, STRAIN = 9;
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

	class Output {
		public string dirname { get; private set; }
		StringBuilder makerules;
		ArrayList<Xml.Node*> samples;
		StringBuilder seqrule;
		StringBuilder seqsources;
		int sequence_preparations;
		string sourcefile;
		public HashMap<string, string> vars { get; private set; }
		Set<string> summarized_otus;
		StringBuilder targets = new StringBuilder();

		public Output(string dirname, string sourcefile) {
			this.dirname = dirname;
			this.sourcefile = realpath(sourcefile);

			sequence_preparations = 0;
			makerules = new StringBuilder();
			samples = new ArrayList<Xml.Node*>();
			seqrule = new StringBuilder();
			seqrule.printf("\ttest ! -f seq.fasta || rm seq.fasta\n");
			seqsources = new StringBuilder();
			summarized_otus = new HashSet<string>();
			targets = new StringBuilder();
			vars = new HashMap<string, string>();
		}

		public bool generate_mapping() {
			var mapping = FileStream.open(Path.build_path(Path.DIR_SEPARATOR_S, dirname, "mapping.txt"), "w");
			if (mapping == null) {
				stderr.printf("%s: Cannot create mapping file.\n", dirname);
				return false;
			}
			mapping.printf("#SampleID");
			foreach (var label in vars.keys) {
				mapping.printf("\t%s", label);
			}
			mapping.printf("\n");
			for (var it = 0; it < samples.size; it++) {
				var sample = samples[it];
				mapping.printf("%d", it);
				foreach (var entry in vars.entries) {
					var prop = sample-> get_prop(entry.key);
					if (prop == null) {
						stderr.printf("%s: %d: Missing attribute %s.\n", sample-> doc-> url, sample-> line, entry.key);
						mapping.printf("\t");
					} else {
						if (entry.value == "s") {
							/* For strings, we are going to side step the Variant stuff because we want the XML to look like foo="bar" rather than foo="'bar'" as Variants would have it. */
							mapping.printf("\t%s", prop);
						} else {
							try {
								var value = Variant.parse(new VariantType(entry.value), prop);
								mapping.printf("\t%s", value.print(false));
							} catch(GLib.VariantParseError e) {
								stderr.printf("%s: %d: Attribute %s:%s = \"%s\" is not of the correct format.\n", sample-> doc-> url, sample-> line, entry.key, entry.value, prop);
								mapping.printf("\t");
							}
						}
					}
				}
				mapping.printf("\n");
			}
			mapping = null;
			return true;
		}

		public bool generate_makefile(RuleLookup lookup) {
			var now = Time.local(time_t());
			var makefile = FileStream.open(Path.build_path(Path.DIR_SEPARATOR_S, dirname, "Makefile"), "w");
			if (makefile == null) {
				stderr.printf("%s: Cannot create Makefile.\n", dirname);
				return false;
			}

			makefile.printf("# Generated by AutoQIIME from %s on %s\n# Modify at your own peril!\n\nall: Makefile mapping.txt otu_table.txt %s\n\n", sourcefile, now.to_string(), targets.str);
			makefile.printf("Makefile mapping.txt: %s\n\tautoqiime $<\n\n", sourcefile);
			makefile.printf("SEQSOURCES = %s\n\nseq.fasta:$(SEQSOURCES)\n%s\n", seqsources.str, seqrule.str);
			makefile.printf("%s\n.PHONY: all\n\ninclude /Winnebago/apmasell/tools/bin-common/qiime_setup\n", makerules.str);
			lookup.print_include(makefile);
			makefile = null;
			return true;
		}
		public void make_summarized_otu(TaxonomicLevel level, string flavour) {
			var taxname = level.to_string();
			var taxindex = (int) level;
			var type = "%s%s".printf(taxname, flavour);
			if (!(type in summarized_otus)) {
				summarized_otus.add(type);
				makerules.append_printf("otu_table_summarized_%s%s.txt: otu_table%s.txt\n\tsummarize_taxa.py -i otu_table%s.txt -L %d -o otu_table_summarized_%s%s.txt -a\n\n", taxname, flavour, flavour, flavour, taxindex, taxname, flavour);
			}
		}

		public void add_target(string file) {
			targets.append_printf(" %s", file);
		}
		public void add_sequence_source(string file) {
			seqsources.append_printf(" %s", file);
		}
		public void add_rule([PrintfFormat] string format, ...) {
			var va = va_list();
			makerules.append_vprintf(format, va);
		}

		public int add_sample(Xml.Node *sample) {
			samples.add(sample);
			return samples.size-1;
		}
		public void prepare_sequences(string prep, HashMap<string, int> samplelookup) {
			var awkprint = new StringBuilder();
			foreach (var entry in samplelookup.entries) {
				awkprint.append_printf("if (name ~ /%s/) { print \">%d_\" NR \"\\n\" seq; }", entry.key, entry.value);
			}
			seqrule.append_printf("\t(%s | awk '/^>/ { if (seq) {%s } name = substr($$0, 2); seq = \"\"; } $$0 !~ /^>/ {seq = seq $$0; } END { if (seq) {%s }}' >> seq.fasta) 2>&1 | bzip2 > seq_%d.log.bz2\n\n", prep, awkprint.str, awkprint.str, sequence_preparations++);
		}
	}

	public void definition_error(Xml.Node *node, [PrintfFormat] string format, ...) {
		stderr.printf("%s: %d: ", node-> doc-> url, node-> line);
		var va = va_list();
		stderr.printf(format, va);
	}

	enum FileCompression {
		PLAIN, GZIP, BZIP;

		public string get_cat() {
			switch (this) {
			case FileCompression.GZIP :
				return "zcat";
			case FileCompression.BZIP :
				return "bzcat";
			default :
				return "cat";
			}
		}

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

	class RuleLookup {
		RuleType state;
		HashMap<string, RuleProcessor> table;
		HashSet<string> seen;
		public RuleLookup() {
			state = RuleType.DEFINITON;
			table = new HashMap<string, RuleProcessor>();
			seen = new HashSet<string>();
		}
		public void reset() {
			state = RuleType.DEFINITON;
		}

		public void print_include(FileStream stream) {
			foreach (var rule in table.values) {
				var file = rule.get_include();
				if (file != null) {
					stream.printf("include %s\n", file);
				}
			}
		}
		public RuleProcessor ? @get(string name) {
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

		public void add(owned RuleProcessor processor) {
			var name = processor.get_name();
			table[name] = (owned) processor;
		}
	}

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

	int main(string[] args) {
		if (args.length != 2) {
			stderr.printf("Usage: %s config.aq\n", args[0]);
			return 1;
		}
		Xml.Doc *doc = Parser.parse_file(args[1]);
		if (doc == null) {
			stderr.printf("%s: unable to read or parse file\n", args[1]);
			return 1;
		}

		Xml.Node *root = doc-> get_root_element();
		if (root == null) {
			delete doc;
			stderr.printf("%s: no data in file\n", args[1]);
			return 1;
		}

		var dirname = (args[1].has_suffix(".aq") ? args[1].substring(0, args[1].length-3) : args[1]).concat(".qiime");
		var output = new Output(dirname, args[1]);

		var lookup = new RuleLookup();
		lookup.add(new Definition());
		lookup.add(new Analyses.AlphaDiversity());
		lookup.add(new Analyses.BetaDiversity());
		lookup.add(new Analyses.BlastDatabase());
		lookup.add(new Analyses.LibraryComparison());
		lookup.add(new Analyses.QualityAnalysis());
		lookup.add(new Analyses.RankAbundance());
		lookup.add(new Sources.FastaSource());
		lookup.add(new Sources.PandaSource());

		for (Xml.Node *iter = root-> children; iter != null; iter = iter-> next) {
			if (iter-> type != ElementType.ELEMENT_NODE) {
				continue;
			}

			var rule = lookup[iter-> name];
			if (rule == null) {
				stderr.printf("%s: %d: The directive `%s' is either unknown, in the wrong place, or duplicated.\n", args[1], iter-> line, iter-> name);
				delete doc;
				return 1;
			}
			if (!rule.process(iter, output)) {
				delete doc;
				return 1;
			}
		}
		stdout.printf("Creating directory...\n");
		if (DirUtils.create_with_parents(dirname, 0755) == -1) {
			stderr.printf("%s: %s\n", dirname, strerror(errno));
			delete doc;
			return 1;
		}

		stdout.printf("Generating mapping file...\n");
		var state = output.generate_mapping();
		if (state) {
			stdout.printf("Generating makefile...\n");
			state = output.generate_makefile(lookup);
		}
		delete doc;
		return state ? 0 : 1;
	}
}
