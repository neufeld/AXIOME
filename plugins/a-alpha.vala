/**
 * Produce alpha diversity statistics
 *
 * Do basic alpha diversity analysis using QIIME's script.
 */
class AXIOME.Analyses.AlphaDiversity : RuleProcessor {
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "alpha";
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
		var pipeline = output.pipeline;
		if (pipeline.to_string() == "mothur") {
			output.add_target("alpha-chao.pdf");
			output.add_rule("mothur_seqs/seq.unique.filter.$(OTU_PICKING_METHOD).groups.r_chao: mothur_seqs/seq.unique.filter.$(OTU_PICKING_METHOD).shared\n\t@echo Performing alpha rarefaction using chao...\n\t$(V)mothur \"#rarefaction.single(shared=mothur_seqs/seq.unique.filter.$(OTU_PICKING_METHOD).shared, label=$(CLUSTER_IDENT), calc=chao)\"\n\n");
			output.add_rule("alpha-chao.pdf: mothur_seqs/seq.unique.filter.$(OTU_PICKING_METHOD).groups.r_chao\n\t@echo Plotting alpha rarefaction curves...\n\t$(V)aq-mothur-alpha -i mothur_seqs/seq.unique.filter.$(OTU_PICKING_METHOD).groups.r_chao -e mapping.extra -o . > /dev/null\n\n");
		} else if (pipeline.to_string() == "qiime") {
			output.add_target("alpha_div/alpha_rarefaction_plots/rarefaction_plots.html");
			output.add_rule("alpha_div/alpha_rarefaction_plots/rarefaction_plots.html: otu_table.txt mapping.txt seq.fasta_rep_set_aligned_pfiltered.tre\n\t@echo Computing Alpha Diversity...\n\t@test ! -d rarefaction_tables || rm -r rarefaction_tables\n\t@test ! -d alpha_div || rm -r alpha_div\n\t$(V)echo 'alpha_diversity:metrics\tshannon,chao1,observed_species' > alpha_params.txt\nifdef MULTICORE\n\t$(V)$(QIIME_PREFIX)alpha_rarefaction.py -i otu_table.txt -m mapping.txt -t seq.fasta_rep_set_aligned_pfiltered.tre -o alpha_div -p alpha_params.txt -a -O $(NUM_CORES)\nelse\n\t$(V)$(QIIME_PREFIX)alpha_rarefaction.py -i otu_table.txt -m mapping.txt -t seq.fasta_rep_set_aligned_pfiltered.tre -o alpha_div -p alpha_params.txt\nendif\n\t$(V)mv alpha_params.txt alpha_div\n\n");
		}
		return true;
	}
}
