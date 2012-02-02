using Gee;

int main(string[] args) {
	if (args.length != 3) {
		stderr.printf("Usage: %s seq.fasta_rep_set.fasta otu_table.txt\n", args[0]);
		return 1;
	}
	stderr.printf("Opening FASTA...\n");
	var sequences = IndexedFasta.open(args[1]);
	if (sequences == null) {
		return 1;
	}
	stderr.printf("Opening OTU table...\n");
	var otu = FileStream.open(args[2], "r");
	if (otu == null) {
		return 1;
	}

	string line;
	if ((line = otu.read_line()) == null) {
		return 1;
	}
	stdout.printf("%s\n", line);
	if ((line = otu.read_line()) == null) {
		return 1;
	}
	stdout.printf("%s\tReprSequence\n", line);
	while ((line = otu.read_line()) != null) {
		var parts = line.split("\t");
		if (parts.length == 0) {
			stderr.printf("Malformed line: %s\n", line);
			continue;
		}
		stdout.printf("%s\t%s\n", line, sequences[parts[0]]);
	}
	return 0;
}
