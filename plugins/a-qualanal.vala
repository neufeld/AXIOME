/**
 * Perform quality analysis on the raw read data
 *
 * Quality analysis is done by a makefile, so it only needs to know the FASTQ files that are included. It can handle anything except the really old 1.3 files.
 */
class AutoQIIME.Analyses.QualityAnalysis : RuleProcessor {
	private string include = bin_dir("aq-qualityanal");
	public override RuleType get_ruletype() {
		return RuleType.ANALYSIS;
	}
	public override unowned string get_name() {
		return "qualityanal";
	}
	public override unowned string ? get_include() {
		return include;
	}
	public override version introduced_version() {
		return version(1, 1);
	}
	public override bool is_only_once() {
		return true;
	}
	public override bool process(Xml.Node *definition, Output output) {
		output.add_target("qualityanal");
		output["FASTQFILES"] = "$(basename $(basename $(filter %.fastq.bz2 %.fastq.gz, $(SEQSOURCES))))";
		return true;
	}
}
