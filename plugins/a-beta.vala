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
			output.add_rulef("otu_table_auto.txt: otu_table.txt\n\t$(QIIME_PREFIX)single_rarefaction.py -i otu_table.txt -o otu_table_auto.txt %s -d $$(awk -F '\t' 'NR == 1 {} NR == 2 { for (i = 2; i <= NF; i++) { if ($$i ~ /^[0-9]*$$/) { max = i; }}} NR > 2 { for (i = 2; i <= max; i++) { c[i] += $$i; }} END { smallest = c[2]; for (i = 3; i <= max; i++) { if (c[i] < smallest) { smallest = c[i]; }} print smallest;}' otu_table.txt)\n\n", is_version_at_least(1, 3) ? "" : "--lineages_included");
		} else {
			int v = int.parse(size);
			if (v < 1) {
				definition_error(definition, "Cannot rareify to a size of \"%s\". Use a positive number or \"auto\".\n", size);
				return false;
			}
			flavour = "_%d".printf(v);
			output.add_rulef("otu_table_%d.txt: otu_table.txt\n\t$(QIIME_PREFIX)single_rarefaction.py -i otu_table.txt -o otu_table_auto.txt -d %d %s\n\n", v, v, is_version_at_least(1, 3) ? "" : "--lineages_included");
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

		output.add_rule(@"prefs_$(taxname)$(flavour).txt: otu_table_summarized_$(taxname)$(flavour).txt\n\t$$(QIIME_PREFIX)make_prefs_file.py -i otu_table_summarized_$(taxname)$(flavour).txt  -m mapping.txt -k white -o prefs_$(taxname)$(flavour).txt\n\n");
		output.add_rule(@"biplot_coords_$(taxname)$(flavour).txt: beta_div_pcoa$(flavour)/pcoa_weighted_unifrac_otu_table.txt prefs_$(taxname)$(flavour).txt otu_table_summarized_$(taxname)$(flavour).txt\n\ttest ! -d biplot$(taxname)$(flavour) || rm -rf biplot$(taxname)$(flavour)\n\t$$(QIIME_PREFIX)make_3d_plots.py -t otu_table_summarized_$(taxname)$(flavour).txt -i beta_div_pcoa$(flavour)/pcoa_weighted_unifrac_otu_table$(flavour).txt -m mapping.txt -p prefs_$(taxname)$(flavour).txt -o biplot$(taxname)$(flavour) --biplot_output_file biplot_coords_$(taxname)$(flavour).txt --n_taxa_keep=$(taxakeep)\n\n");
		output.add_rule(@"biplot_$(taxname)$(flavour).svg: biplot_coords_$(taxname)$(flavour).txt mapping.extra\n\taq-biplot \"$(taxname)\" \"$(flavour)\"\n\n");
		output.add_rule(@"bubblelot_$(taxname)$(flavour).svg: biplot_coords_$(taxname)$(flavour).txt mapping.extra\n\taq-bubbleplot \"$(taxname)\" \"$(flavour)\"\n\n");

		output.add_target(@"biplot_coords_$(taxname)$(flavour).txt");
		return true;
	}
}
