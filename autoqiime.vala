using GLib;
using Gee;
using Xml;

namespace AutoQIIME {

	public HashMap<string, string> primers;
	[CCode(cname = "DATADIR")]
	extern const string DATADIR;
	[CCode(cname = "BINDIR")]
	extern const string BINDIR;

	/**
	 * Type of stanzas in the XML input document.
	 */
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

	public bool is_sequence(string sequence) {
		return Regex.match_simple("^[ACGTKMSWRYBDHV]*$", sequence);
	}

	/**
	 * Source of sequence data
	 */
	namespace Sources {

		/**
		 * Copy data from existing FASTA files
		 *
		 * Read a FASTA file into seq.fasta and pull sequences with ids matching specific regular expressions.
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
				var limits = new HashMap<string, int>();
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
					var limit = sample-> get_prop("limit");
					if (limit != null) {
						var limitval = int.parse(limit);
						if (limitval > 0) {
							limits[regexstr] = limitval;
						}
					}
				}

				output.add_sequence_source(file);
				var command = "%s %s".printf(FileCompression.for_file(file).get_cat(), Shell.quote(file));
				output.prepare_sequences(command, subst, limits);
				return true;
			}
		}

		/**
		 * Assemble data using PANDAseq from Illumina files.
		 *
		 * Calls PANDAseq and pulls out specific indecies.
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
			private void add_primer(StringBuilder command, Xml.Node *definition, string name, char arg) {
				var primer = definition-> get_prop(name);
				if (primer != null) {
					primer = primer.up();
					if (primer[0] == '#') {
						primer = primer.substring(1);
						if (primers.has_key(primer)) {
							command.append_printf(" -%c %d", arg, primers[primer].length);
						} else {
							definition_error(definition, "Unknown primer %s. Ignorning, mumble, mumble.\n", primer);
						}
					} else if (primers.has_key(primer)) {
						command.append_printf(" -%c %s", arg, Shell.quote(primers[primer]));
					} else if (Regex.match_simple("^\\d+$", primer) || is_sequence(primer)) {
						command.append_printf(" -%c %s", arg, Shell.quote(primer));
					} else {
						definition_error(definition, "Invalid primer %s. Ignorning, mumble, mumble.\n", primer);
					}
				}
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

				/* How we process this file depends on what version of CASAVA created the FASTQ files. The old ones need to be converted. We also need to know if they are bzipped so we can give the -j option to PANDAseq. */
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
					output.add_rule("%s: %s\n\tzcat %s | aq-oldillumina2fastq > %s\n\n%s: %s\n\tzcat %s | aq-oldillumina2fastq > %s\n\n", forward, oldforward, oldforward, forward, reverse, oldreverse, oldreverse, reverse);
					domagic = false;
					dashj = true;
				}

				if (domagic) {
					dashj = FileCompression.for_file(forward) == FileCompression.BZIP;
				}

				var subst = new HashMap<string, int>();
				var limits = new HashMap<string, int>();
				for (Xml.Node *sample = definition-> children; sample != null; sample = sample-> next) {
					if (sample-> type != ElementType.ELEMENT_NODE) {
						continue;
					}
					var tag = sample-> get_prop("tag");
					if (sample-> name != "sample" || tag == null || tag == "") {
						definition_error(definition, "Invalid element %s. Ignorning, mumble, mumble.\n", sample-> name);
						continue;
					}
					if (subst.has_key(tag)) {
						definition_error(definition, "Duplicated tag %s. Skipping.\n", tag);
						continue;
					}
					subst[tag] = output.add_sample(sample);
					var limit = sample-> get_prop("limit");
					if (limit != null) {
						var limitval = int.parse(limit);
						if (limitval > 0) {
							limits[tag] = limitval;
						}
					}
				}

				output.add_sequence_source(forward);
				output.add_sequence_source(reverse);
				var command = new StringBuilder();
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
				foreach (var entry in subst.entries) {
					command.append_printf(":%s", entry.key);
				}
				output.prepare_sequences(command.str, subst, limits);
				return true;
			}
		}
	}

	/**
	 * Those things what the user cares about.
	 */
	namespace Analyses {
		/**
		 * Perform quality analysis on the raw read data
		 *
		 * Quality analysis is done by a makefile, so it only needs to know the FASTQ files that are included. It can handle anything except the really old 1.3 files.
		 */
		class QualityAnalysis : RuleProcessor {
			private string include = Path.build_filename(BINDIR, "aq-qualityanal");
			public override RuleType get_ruletype() {
				return RuleType.ANALYSIS;
			}
			public override unowned string get_name() {
				return "qualityanal";
			}
			public override unowned string ? get_include() {
				return include;
			}
			public override bool is_only_once() {
				return true;
			}
			public override bool process(Xml.Node *definition, Output output) {
				output.add_target("qualityanal");
				output["FASTQFILES"] = "$(SEQSOURCES)";
				return true;
			}
		}

		/**
		 * Compare the distribution of taxa between pairs of libraries
		 *
		 * This relies on an R script to do the heavy lifting. A summarized OTU table is needed.
		 */
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
				output.add_rule("correlation_%s.pdf: otu_table_summarized_%s.txt mapping.extra\n\taq-cmplibs %s\n\n", taxname, taxname, taxname);
				return true;
			}
		}

		/**
		 * Produce alpha diversity statistics
		 *
		 * Do basic alpha diversity analysis using QIIME's script.
		 */
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

		/**
		 * Perform a chimera check with uchime
		 */
		class UchimeCheck : RuleProcessor {
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
						definition_error(definition, "Unknown profile `%s'.\n", profile);
						return false;
					}
				}
				for (var i = 0; i < output.sequence_preparations; i++) {
					output.add_target("chimeras%d.uchime".printf(i));
				}
				return true;
			}
		}

		/**
		 * Create a BLAST database for the sequence library
		 *
		 * Call formatdb to create a BLAST database and create a shell script to sensibly handle calling BLAST with decent options.
		 */
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
				output.add_rule("blast: Makefile\n\t@echo '#!/bin/sh' > blast\n\t@echo blastall -p blastn -d \\'%s/nr\\' '\"$$@\"' >> blast\n\tchmod a+x blast\n\n", Shell.quote(realpath(output.dirname)));

				return true;
			}
		}

		/**
		 * Decorate the OTU table with the representative sequences
		 */
		class TableWithSeqs : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.ANALYSIS;
			}
			public override unowned string get_name() {
				return "withseqs";
			}
			public override unowned string ? get_include() {
				return null;
			}
			public override bool is_only_once() {
				return true;
			}
			public override bool process(Xml.Node *definition, Output output) {
				output.add_target("otu_table_with_sequences.txt");
				return true;
			}
		}

		/**
		 * Make a rank-abundance curve using QIIME
		 */
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

		/**
		 * Produce principle component analysis using R
		 *
		 * Do prinicpal component analysis on the taxa and the other (numeric) variables specified.
		 */
		class PrincipalComponentAnalysis : RuleProcessor {
			public override RuleType get_ruletype() {
				return RuleType.ANALYSIS;
			}
			public override unowned string get_name() {
				return "pca";
			}
			public override unowned string ? get_include() {
				return null;
			}
			public override bool is_only_once() {
				return true;
			}
			public override bool process(Xml.Node *definition, Output output) {
				var hasnumeric = false;
				foreach (var type in output.vars.values) {
					if (type == "i" || type == "d") {
						hasnumeric = true;
						break;
					}
				}
				if (!hasnumeric) {
					definition_error(definition, "You should probably have at least one numeric variable over which to do PCA.");
				}
				output.add_target("biplot.pdf");
				return true;
			}
		}

		/**
		 * Produce beta-diversity (UniFrac) analysis using QIIME
		 *
		 * Calling UniFrac using QIIME requires rarefying the OTU table and summarising it to a particular taxonomic level.
		 */
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

				string taxname;
				if (definition-> get_prop("level") == null) {
					taxname = "otu";
				} else {
					var taxlevel = TaxonomicLevel.parse(definition-> get_prop("level"));
					if (taxlevel == null) {
						definition_error(definition, "Unknown taxonomic level \"%s\" in beta diversity analysis.\n", definition-> get_prop("level"));
						return false;
					}
					taxname = taxlevel.to_string();
					output.make_summarized_otu(taxlevel, flavour);
				}
				var numtaxa = definition-> get_prop("taxa");
				int taxakeep;
				if (numtaxa == null) {
					taxakeep = 10;
				} else if (numtaxa == "all") {
					taxakeep = -1;
				} else {
					taxakeep = int.parse(numtaxa);
					if (taxakeep == 0) {
						taxakeep = 10;
					}
				}

				output.add_rule("prefs_%s%s.txt: otu_table_summarized_%s%s.txt\n\tmake_prefs_file.py -i otu_table_summarized_%s%s.txt  -m mapping.txt -k white -o prefs_%s%s.txt\n\n", taxname, flavour, taxname, flavour, taxname, flavour, taxname, flavour);
				output.add_rule("biplot_coords_%s%s.txt: beta_div_pcoa%s/pcoa_weighted_unifrac_otu_table.txt prefs_%s%s.txt otu_table_summarized_%s%s.txt\n\ttest ! -d biplot%s%s || rm -rf biplot%s%s\n\tmake_3d_plots.py -t otu_table_summarized_%s%s.txt -i beta_div_pcoa%s/pcoa_weighted_unifrac_otu_table%s.txt -m mapping.txt -p prefs_%s%s.txt -o biplot%s%s --biplot_output_file biplot_coords_%s%s.txt --n_taxa_keep=%d\n\n", taxname, flavour, flavour, taxname, flavour, taxname, flavour, taxname, flavour, taxname, flavour, taxname, flavour, flavour, flavour, taxname, flavour, taxname, flavour, taxname, flavour, taxakeep);
				output.add_rule("biplot_%s%s.svg: biplot_coords_%s%s.txt mapping.extra\n\taq-biplot %s%s\n\n", taxname, flavour, taxname, flavour, taxname, flavour);
				output.add_rule("bubblelot_%s%s.svg: biplot_coords_%s%s.txt mapping.extra\n\taq-bubbleplot %s%s\n\n", taxname, flavour, taxname, flavour, taxname, flavour);

				output.add_target("biplot_coords_%s%s.txt".printf(taxname, flavour));
				return true;
			}
		}
	}

	/**
	 * Friendly names for taxnomic levels as used by QIIME/RDP
	 */
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

	/**
	 * Output processor responsible for collecting all information needed to generate the Makefile and mapping.txt
	 */
	class Output {
		public string dirname { get; private set; }
		StringBuilder makerules;
		ArrayList<Xml.Node*> samples;
		StringBuilder seqrule;
		StringBuilder seqsources;
		public int sequence_preparations { get; private set; }
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

		/**
		 * Output the mapping.txt file in the appropriate directory.
		 */
		public bool generate_mapping() {
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
			for (var it = 0; it < samples.size; it++) {
				var sample = samples[it];
				mapping.append_printf("%d", it);
				extra.append_printf("%d", it);
				foreach (var entry in vars.entries) {
					var prop = sample-> get_prop(entry.key);
					if (prop == null) {
						stderr.printf("%s: %d: Missing attribute %s.\n", sample-> doc-> url, sample-> line, entry.key);
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
								stderr.printf("%s: %d: Attribute %s:%s = \"%s\" is not of the correct format.\n", sample-> doc-> url, sample-> line, entry.key, entry.value, prop);
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
		public bool generate_makefile(RuleLookup lookup) {
			var now = Time.local(time_t());
			var makefile = FileStream.open(Path.build_filename(dirname, "Makefile"), "w");
			if (makefile == null) {
				stderr.printf("%s: Cannot create Makefile.\n", dirname);
				return false;
			}

			makefile.printf("# Generated by AutoQIIME from %s on %s\n# Modify at your own peril!\n\nall: Makefile mapping.txt otu_table.txt %s\n\n", sourcefile, now.to_string(), targets.str);
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
			var type = "%s%s".printf(taxname, flavour);
			if (!(type in summarized_otus)) {
				summarized_otus.add(type);
				makerules.append_printf("otu_table_summarized_%s%s.txt: otu_table%s.txt\n\tsummarize_taxa.py -i otu_table%s.txt -L %d -o otu_table_summarized_%s%s.txt -a\n\n", taxname, flavour, flavour, flavour, taxindex, taxname, flavour);
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
		public void set(string key, string value) {
			makerules.append_printf("%s = %s\n\n", key, value);
		}

		/**
		 * Register an XML “sample” element containing attributes satisfying the metadata requirements of the “defs”.
		 *
		 * @return the unique identifier for a sample. This must be associated with the map used in {@link prepare_sequences}.
		 */
		public int add_sample(Xml.Node *sample) {
			samples.add(sample);
			return samples.size-1;
		}

		/**
		 * Create a rule to extract sequence data from a command.
		 *
		 * It is assumed the supplied command will output FASTA data. The FASTA sequences will be binned into samples and the error output will be saved to a file.
		 * @param prep the command to prepare the sequence
		 * @param samplelookup a mapping between regular expressions and sample identifiers. The regular expressions are used by AWK to convert the sequence names to QIIME-friendly format. Any sequences not matched by a regular expression in this dictionary will be discarded.
		 * @param samplelimits a list of the maximum number of sequences in this sample, or, missing or 0 if there is no limit.
		 */
		public void prepare_sequences(string prep, HashMap<string, int> samplelookup, HashMap<string, int> samplelimits) {
			var awkprint = new StringBuilder();
			foreach (var entry in samplelookup.entries) {
				awkprint.append_printf("if (name ~ /%s/", entry.key);
				if (samplelimits.has_key(entry.key) && samplelimits[entry.key] > 0) {
					awkprint.append_printf(" && count%d < %d", entry.value, samplelimits[entry.key]);
				}
				awkprint.append_printf(") { print \">%d_\" NR \"\\n\" seq; count%d++; }", entry.value, entry.value);
			}
			seqrule.append_printf("\t(%s | awk '/^>/ { if (seq) {%s } name = substr($$0, 2); seq = \"\"; } $$0 !~ /^>/ {seq = seq $$0; } END { if (seq) {%s }}' >> seq.fasta) 2>&1 | bzip2 > seq_%d.log.bz2\n\n", prep, awkprint.str, awkprint.str, sequence_preparations++);
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
	enum FileCompression {
		PLAIN, GZIP, BZIP;

		/**
		 * Get the tool that one would use to render the file to plain text.
		 */
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

		/**
		 * Register a new file processor.
		 */
		public void add(owned RuleProcessor processor) {
			var name = processor.get_name();
			table[name] = (owned) processor;
		}
	}

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

		stdout.printf("Creating directory...\n");
		if (DirUtils.create_with_parents(dirname, 0755) == -1) {
			stderr.printf("%s: %s\n", dirname, strerror(errno));
			delete doc;
			return 1;
		}

		/* Build a lookup for all the rules we know about. If you need to add a new one, add it here, alphabetically please. */
		var lookup = new RuleLookup();
		lookup.add(new Definition());
		lookup.add(new Analyses.AlphaDiversity());
		lookup.add(new Analyses.BetaDiversity());
		lookup.add(new Analyses.BlastDatabase());
		lookup.add(new Analyses.LibraryComparison());
		lookup.add(new Analyses.PrincipalComponentAnalysis());
		lookup.add(new Analyses.QualityAnalysis());
		lookup.add(new Analyses.RankAbundance());
		lookup.add(new Analyses.TableWithSeqs());
		lookup.add(new Analyses.UchimeCheck());
		lookup.add(new Sources.FastaSource());
		lookup.add(new Sources.PandaSource());

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
			stderr.printf("Warning: Couldn't find the primers list in `%s'.\n", DATADIR);
		}

		/* Iterate over the XML document and call all the appropriate rules. */
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

		/* Generate the Makefile and mapping.txt. */
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
