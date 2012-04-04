/**
 * Produce beta-diversity (UniFrac) analysis using QIIME
 *
 * Calling UniFrac using QIIME requires rarefying the OTU table and summarising it to a particular taxonomic level.
 */
class AutoQIIME.Analyses.BetaDiversity : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "beta";
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
				definition_error(definition, "Cannot rareify to a size of \"%s\". Use a positive number or \"auto\".\n", size);
				return false;
			}
			flavour = "_%d".printf(v);
			output.make_rarefied(v);
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

		output.make_pcoa(flavour);
		output.add_rule(@"prefs_$(taxname)$(flavour).txt: otu_table_summarized_$(taxname)$(flavour).txt\n\t@echo Producing biplot preferences $(flavour) at $(taxname)-level...\n\t$$(V)$$(QIIME_PREFIX)make_prefs_file.py -i otu_table_summarized_$(taxname)$(flavour).txt -m mapping.txt -k $(definition-> get_prop("background") ?? "white") -o prefs_$(taxname)$(flavour).txt\n\n");
		output.add_rule(@"biplot_coords_$(taxname)$(flavour).txt: beta_div_pcoa$(flavour)/pcoa_weighted_unifrac_otu_table.txt prefs_$(taxname)$(flavour).txt otu_table_summarized_$(taxname)$(flavour).txt\n\t@echo Producing biplot 3D image $(flavour) at $(taxname)-level...\n\t$$(V)test ! -d biplot$(taxname)$(flavour) || rm -rf biplot$(taxname)$(flavour)\n\t$$(V)$$(QIIME_PREFIX)make_3d_plots.py -t otu_table_summarized_$(taxname)$(flavour).txt -i beta_div_pcoa$(flavour)/pcoa_weighted_unifrac_otu_table$(flavour).txt -m mapping.txt -p prefs_$(taxname)$(flavour).txt -o biplot$(taxname)$(flavour) --biplot_output_file biplot_coords_$(taxname)$(flavour).txt --n_taxa_keep=$(taxakeep)\n\n");
		output.add_rule(@"biplot_$(taxname)$(flavour).svg: biplot_coords_$(taxname)$(flavour).txt mapping.extra\n\t@echo Producing biplot SVG $(flavour) at $(taxname)-level...\n\t$$(V)aq-biplot \"$(taxname)\" \"$(flavour)\"\n\n");
		output.add_rule(@"bubbleplot_$(taxname)$(flavour).svg: biplot_coords_$(taxname)$(flavour).txt mapping.extra\n\t@echo Producing bubbleplot SVG $(flavour) at $(taxname)-level...\n\t$$(V)aq-bubbleplot \"$(taxname)\" \"$(flavour)\"\n\n");

		output.add_target(@"biplot_coords_$(taxname)$(flavour).txt");
		return true;
	}
}
