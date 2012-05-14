using Gee;

int main(string[] args) {
	if (args.length != 3) {
		stderr.printf("Usage: %s seq.fasta_rep_set.fasta otu_table.tab\n", args[0]);
		return 1;
	}
	stderr.printf("Opening FASTA...\n");
	var sequences = IndexedFasta.open(args[1]);
	if (sequences == null) {
		stderr.printf("Could not open %s: %s\n", args[1], strerror(errno));
		return 1;
	}
	stderr.printf("Opening OTU table...\n");
	var otu = FileStream.open(args[2], "r");
	if (otu == null) {
		stderr.printf("Could not open %s: %s\n", args[2], strerror(errno));
		return 1;
	}

	string line;
	long count = 0;
	if ((line = otu.read_line()) == null) {
		stderr.printf("OTU table ended prematurely.\n");
		return 1;
	}
	stdout.printf("%s\n", line);
	if ((line = otu.read_line()) == null) {
		stderr.printf("OTU table ended prematurely.\n");
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
		count++;
		if (count % 100000 == 0) {
			stderr.printf("Married %ld sequences...\n", count);
		}
	}
	stderr.printf("Married %ld sequences...\n", count);
	return 0;
}
