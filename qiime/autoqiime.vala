using GLib;
using Gee;
using RealPath;
using Xml;

enum ParsingState { DEFS, FILES, ANALYSES }

enum TaxonomicLevel { LIFE = 1, DOMAIN = 2, PHYLUM = 3, CLASS = 4, ORDER = 5, FAMILY = 6, GENUS = 7, SPECIES = 8, STRAIN = 9;
	              public static TaxonomicLevel ? parse(string name) {
			      var enum_class = (EnumClass) typeof(TaxonomicLevel).class_ref ();
			      var nick = name.down().replace ("_", "-");
			      unowned GLib.EnumValue ? enum_value = enum_class.get_value_by_nick (nick);
			      if (enum_value != null) {
				      TaxonomicLevel value = (TaxonomicLevel) enum_value.value;
				      return value;
			      }
			      return null;
		      }
	              public string to_string() {
			      return ((EnumClass)typeof (TaxonomicLevel).class_ref ()).get_value(this).value_nick;
		      }
}

Set<string> summarized_otus;
void make_summarized_otu (StringBuilder makerules, TaxonomicLevel level, string flavour) {
	var taxname = level.to_string();
	var taxindex = (int) level;
	var type = "%s%s".printf(taxname, flavour);
	if (!(type in summarized_otus)) {
		summarized_otus.add(type);
		makerules.append_printf("otu_table_summarized_%s%s.txt: otu_table%s.txt\n\tsummarize_taxa.py -i otu_table%s.txt -L %d -o otu_table_summarized_%s%s.txt -a\n\n", taxname, flavour, flavour, flavour, taxindex, taxname, flavour);
	}
}

int main(string[] args) {
	if (args.length != 2) {
		stderr.printf("Usage: %s config.aq\n", args[0]);
		return 1;
	}
	Xml.Doc* doc = Parser.parse_file(args[1]);
	if (doc == null) {
		stderr.printf("%s: unable to read or parse file\n", args[1]);
		return 1;
	}

	Xml.Node* root = doc->get_root_element();
	if (root == null) {
		delete doc;
		stderr.printf("%s: no data in file\n", args[1]);
		return 1;
	}
	summarized_otus = new HashSet<string>(str_hash, str_equal);
	var state = ParsingState.DEFS;
	var vars = new HashMap<string, string>(str_hash, str_equal);
	var samples = new ArrayList<Xml.Node*>();
	var magic = new LibMagic.Magic (LibMagic.Flags.SYMLINK | LibMagic.Flags.MIME_TYPE);
	magic.load();
	var seqsources = new StringBuilder();
	var seqrule = new StringBuilder();
	var targets = new StringBuilder();
	var makerules = new StringBuilder();
	seqrule.printf("\ttest ! -f seq.fasta || rm seq.fasta\n");

	for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
		if (iter->type != ElementType.ELEMENT_NODE)
			continue;

		if (state == ParsingState.DEFS) {
			if (iter->name == "def") {
				var name = iter->get_prop("name");
				if (name == null) {
					stderr.printf("%s: %d: Definition missing name.\n", args[1], iter->line);
					delete doc;
					return 1;
				}
				if (vars.has_key(name)) {
					stderr.printf("%s: %d: Duplicate definition of %s.\n", args[1], iter->line, name);
					delete doc;
					return 1;
				}
				var type = iter->get_prop("type");
				if (type == null) {
					vars[name] = "s";
				} else if (VariantType.string_is_valid(type)) {
					vars[name] = type;
				} else {
					stderr.printf("%s: %d: Invalid type %s for %s.\n", args[1], iter->line, type, name);
					delete doc;
					return 1;
				}
				continue;
			}
		}
		if (state == ParsingState.FILES || state == ParsingState.DEFS) {
			if (iter->name == "panda") {
				state = ParsingState.FILES;
				var forward = iter->get_prop("forward");
				if (forward == null) {
					stderr.printf("%s: %d: Forward file not specified.\n", args[1], iter->line);
					delete doc;
					return 1;
				}
				if (!FileUtils.test(forward, FileTest.EXISTS)) {
					stderr.printf("%s: File does not exist.\n", forward);
					delete doc;
					return 1;
				}

				var reverse = iter->get_prop("reverse");
				if (reverse == null) {
					stderr.printf("%s: %d: Reverse file not specified.\n", args[1], iter->line);
					delete doc;
					return 1;
				}
				if (!FileUtils.test(reverse, FileTest.EXISTS)) {
					stderr.printf("%s: File does not exist.\n", reverse);
					delete doc;
					return 1;
				}

				bool dashj = false;
				bool dashsix;
				bool domagic;
				bool convert;

				var version = iter->get_prop("version");
				if (version == null) {
					stderr.printf("%s: %d: No version specified. I'm going to assume you have the latest version.\n", args[1], iter->line);
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
					stderr.printf("%s: %d: The version `%s' is not one that I recognise. You should probably do something about that. Until then, I'm going to make some assumptions.\n", args[1], iter->line, version);
					domagic = true;
					convert = false;
					dashsix = false;
				}

				if (convert) {
					var oldsuffix = "_sequence.txt.gz";
					var oldforward = forward;
					var oldreverse = reverse;
					forward = (forward.has_suffix(oldsuffix) ? forward.substring(0, forward.length - oldsuffix.length) : forward).concat(".fastq.bz2");
					reverse = (reverse.has_suffix(oldsuffix) ? reverse.substring(0, reverse.length - oldsuffix.length) : reverse).concat(".fastq.bz2");
					makerules.append_printf("%s: %s\n\tzcat %s | oldillumina2fastq > %s\n\n%s: %s\n\tzcat %s | oldillumina2fastq > %s\n\n", forward, oldforward, oldforward, forward, reverse, oldreverse, oldreverse, reverse);
					domagic = false;
					dashj = true;
				}

				if (domagic) {
					var mime = magic.file(forward);
					dashj = (mime != null && mime.has_prefix("application/x-bzip2"));
				}

				var subst = new HashMap<string, int>(str_hash, str_equal);
				for (Xml.Node* sample = iter->children; sample != null; sample = sample->next) {
					if (sample->type != ElementType.ELEMENT_NODE)
						continue;
					if (sample->name != "sample" || sample->get_prop("tag") == null) {
						stderr.printf("%s: %d: Invalid element %s. Ignorning, mumble, mumble.\n", args[1], iter->line, sample->name);
						continue;
					}
					samples.add(sample);
					subst[sample->get_prop("tag")] = samples.size - 1;
				}

				seqsources.append_printf(" %s %s", forward, reverse);
				seqrule.append_printf("\t(pandaseq -N -f %s -r %s", Shell.quote(forward), Shell.quote(reverse));

				if (dashj) {
					seqrule.append_printf(" -j");
				}
				if (dashsix) {
					seqrule.append_printf(" -6");
				}
				var fprimer = iter->get_prop("fprimer");
				if (fprimer != null) {
					if (Regex.match_simple("^([ACGTacgt]*)|(\\d*)$", fprimer)) {
						seqrule.append_printf(" -p %s", Shell.quote(fprimer));
					} else {
						stderr.printf("%s: %d: Invalid primer %s. Ignorning, mumble, mumble.\n", args[1], iter->line, fprimer);
					}
				}
				var rprimer = iter->get_prop("rprimer");
				if (rprimer != null) {
					if (Regex.match_simple("^([ACGTacgt]*)|(\\d*)$", rprimer)) {
						seqrule.append_printf(" -q %s", Shell.quote(rprimer));
					} else {
						stderr.printf("%s: %d: Invalid primer %s. Ignorning, mumble, mumble.\n", args[1], iter->line, rprimer);
					}
				}
				var threshold = iter->get_prop("threshold");
				if (threshold != null) {
					seqrule.append_printf(" -t %s", Shell.quote(threshold));
				}
				seqrule.append_printf(" -C /usr/local/lib/pandaseq/validtag.so");
				var awkprint = new StringBuilder();
				foreach (var entry in subst.entries) {
					seqrule.append_printf(":%s", entry.key);
					awkprint.append_printf("if (name ~ /%s/) { print \">%d_\" NR \"\\n\" seq; }", entry.key, entry.value);
				}
				seqrule.append_printf(" | awk '/^>/ { if (seq) {%s } name = $$0; seq = \"\"; } $$0 !~ /^>/ {seq = seq $$0; } END { if (seq) {%s }}' >> seq.fasta ) 2>&1 | bzip2 > pandaseq_%d.log.bz2\n", awkprint.str, awkprint.str, iter->line);
				continue;
			}
		}

		if (iter->name == "alpha") {
			state = ParsingState.ANALYSES;
			targets.append_printf(" alpha");
			continue;
		}

		if (iter->name == "rankabundance") {
			state = ParsingState.ANALYSES;
			targets.append_printf(" rank_abundance/rank_abundance.pdf");
			continue;
		}


		if (iter->name == "qualityanal") {
			state = ParsingState.ANALYSES;
			targets.append_printf(" qualityanal");
			makerules.append_printf("FASTQFILES = %s\n\n", seqsources.str);
			continue;
		}

		if (iter->name == "compare") {
			state = ParsingState.ANALYSES;
			var taxlevel = TaxonomicLevel.parse(iter->get_prop("level"));
			if (taxlevel == null) {
				stderr.printf("%s: %d: Unknown taxonomic level \"%s\" in library abundance comparison analysis.\n", args[1], iter->line, iter->get_prop("level"));
				delete doc;
				return 1;
			}
			var taxname = taxlevel.to_string();
			make_summarized_otu(makerules, taxlevel, "");
			targets.append_printf(" correlation_%s.pdf", taxname);
			makerules.append_printf("correlation_%s.pdf: otu_table_summarized_%s.txt mapping.txt\n\tqiime_cmplibs %s\n\n", taxname, taxname, taxname);
			continue;
		}
		if (iter->name == "beta") {
			state = ParsingState.ANALYSES;

			if (!vars.has_key("Colour") || vars["Colour"] != "s") {
				stderr.printf("%s: %d: Biplots require there to be a \"Colour\" associated with each sample.\n", args[1], iter->line);
			}
			if (!vars.has_key("Description") || vars["Description"] != "s") {
				stderr.printf("%s: %d: Biplots require there to be a \"Description\" associated with each sample.\n", args[1], iter->line);
			}

			string flavour;
			var size = iter->get_prop("size");
			if (size == null) {
				flavour = "";
			} else if (size == "auto") {
				flavour = "_auto";
			} else {
				int v = int.parse(size);
				if (v < 1) {
					stderr.printf("%s: %d: Cannot rareify to a size of `%s'. Use a positive number or `auto'.\n", args[1], iter->line, size);
					continue;
				}
				flavour = "_%d".printf(v);
				makerules.append_printf("otu_table_%d.txt: otu_table.txt\n\tsingle_rarefaction.py -i otu_table.txt -o otu_table_auto.txt --lineages_included -d %d\n\n", v, v);
			}

			var taxlevel = TaxonomicLevel.parse(iter->get_prop("level"));
			if (taxlevel == null) {
				stderr.printf("%s: %d: Unknown taxonomic level \"%s\" in beta diversity analysis.\n", args[1], iter->line, iter->get_prop("level"));
				delete doc;
				return 1;
			}
			var taxname = taxlevel.to_string();

			make_summarized_otu(makerules, taxlevel, flavour);
			makerules.append_printf("prefs_%s%s.txt: otu_table_summarized_%s%s.txt\n\tmake_prefs_file.py -i otu_table_summarized_%s%s.txt  -m mapping.txt -k white -o prefs_%s%s.txt\n\n", taxname, flavour, taxname, flavour, taxname, flavour, taxname, flavour);
			makerules.append_printf("biplot_coords_%s%s.txt: otu_table_summarized_%s%s.txt\n\tmake_3d_plots.py -t otu_table_summarized_%s%s.txt -i beta_div_pcoa%s/pcoa_weighted_unifrac_otu_table.txt -m mapping.txt -p prefs_%s%s.txt -o biplot%s%s --biplot_output_file biplot_coords_%s%s.txt\n\n", taxname, flavour, taxname, flavour, taxname, flavour, flavour, taxname, flavour, taxname, flavour, taxname, flavour);
			makerules.append_printf("biplot_%s%s.svg: biplot_coords_%s%s.txt\n\tbiplot %s%s\n\n", taxname, flavour, taxname, flavour, taxname, flavour);
			makerules.append_printf("bubblelot_%s%s.svg: biplot_coords_%s%s.txt\n\tbubbleplot %s%s\n\n", taxname, flavour, taxname, flavour, taxname, flavour);

			targets.append_printf(" biplot_coords_%s%s.txt", taxname, flavour);
			continue;
		}


		stderr.printf("%s: %d: Unknown instruction %s.\n", args[1], iter->line, iter->name);
		delete doc;
		return 1;
	}

	stdout.printf("Creating directory...\n");
	var dirname = (args[1].has_suffix(".aq") ? args[1].substring(0, args[1].length - 3) : args[1]).concat(".qiime");
	if (DirUtils.create_with_parents(dirname, 0755) == -1) {
		stderr.printf("%s: %s\n", dirname, strerror(errno));
		delete doc;
		return 1;
	}


	stdout.printf("Generating mapping file...\n");
	var mapping = FileStream.open(Path.build_path(Path.DIR_SEPARATOR_S, dirname, "mapping.txt"), "w");
	if (mapping == null) {
		stderr.printf("%s: Cannot create mapping file.\n", dirname);
		delete doc;
		return 1;
	}
	mapping.printf("#SampleID");
	foreach(var label in vars.keys) {
		mapping.printf("\t%s", label);
	}
	mapping.printf("\n");
	for(var it = 0; it < samples.size; it++) {
		var sample = samples[it];
		mapping.printf("%d", it);
		foreach(var entry in vars.entries) {
			var prop = sample->get_prop(entry.key);
			if (prop == null) {
				stderr.printf("%s: %d: Missing attribute %s.\n", args[1], sample->line, entry.key);
				mapping.printf("\t");
			} else {
				if (entry.value == "s") {
					/* For strings, we are going to side step the Variant stuff because we want the XML to look like foo="bar" rather than foo="'bar'" as Variants would have it. */
					mapping.printf("\t%s", prop);
				} else {
					try {
						var value = Variant.parse(new VariantType(entry.value), prop);
						mapping.printf("\t%s", value.print(false));
					} catch (GLib.VariantParseError e) {
						stderr.printf("%s: %d: Attribute %s:%s = \"%s\" is not of the correct format.\n", args[1], sample->line, entry.key, entry.value, prop);
						mapping.printf("\t");
					}
				}
			}
		}
		mapping.printf("\n");
	}
	mapping = null;


	stdout.printf("Generating makefile...\n");
	var now = Time.local(time_t());
	var makefile = FileStream.open(Path.build_path(Path.DIR_SEPARATOR_S, dirname, "Makefile"), "w");
	makefile.printf("# Generated by AutoQIIME from %s on %s\n# Modify at your own peril!\n\nall: Makefile mapping.txt %s\n\n", args[1], now.to_string(), targets.str);
	makefile.printf("Makefile mapping.txt: %s\n\tautoqiime $<\n\n", realpath(args[1]));
	makefile.printf("seq.fasta:%s\n%s\n", seqsources.str, seqrule.str);
	makefile.printf("%s\n.PHONY: all\n\ninclude /Winnebago/apmasell/tools/bin-common/qualityanal /Winnebago/apmasell/tools/bin-common/qiime_setup\n", makerules.str);
	makefile = null;
	delete doc;
	return 0;
}
