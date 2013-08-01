using Gee;

int main(string[] args) {
	if (args.length != 3) {
		stderr.printf("Usage: %s seq.fasta otu_seqs.txt\n", args[0]);
		return 1;
	}
	stderr.printf("Opening FASTA...\n");
	var sequences = IndexedFasta.open(args[1]);
	if (sequences == null) {
		stderr.printf("Could not open %s: %s\n", args[1], strerror(errno));
		return 1;
	}
	stderr.printf("Opening Clusters...\n");
	var clusters = FileStream.open(args[2], "r");
	if (clusters == null) {
		stderr.printf("Could not open %s: %s\n", args[2], strerror(errno));
		return 1;
	}

	string line;
	long count = 0;
	while ((line = clusters.read_line()) != null) {
		var members = line.split("\t");
		if (members.length < 2) {
			stderr.printf("Malformed line: %s\n", line);
			continue;
		}
		var representatives = new HashMap<string, Count>(Gee.Functions.get_hash_func_for(typeof(string)), Gee.Functions.get_equal_func_for(typeof(string)));
		for (var i = 1; i < members.length; i++) {
			var sequence = sequences[members[i]];
			if (sequence == null) {
				stderr.printf("Missing sequence: %s\n", members[i]);
				continue;
			}

			if (representatives.has_key(sequence)) {
				representatives[sequence].val++;
			} else {
				representatives[sequence] = new Count(1);
			}
		}

		long maxcount = 0;
		string maxsequence = "";
		foreach (var entry in representatives.entries) {
			if (entry.value.val > maxcount) {
				maxcount = entry.value.val;
				maxsequence = entry.key;
			}
		}
		stdout.printf(">%s;size=%i\n%s\n", members[0], (members.length - 1), maxsequence);
		count++;
		if (count % 100000 == 0) {
			stderr.printf("Summarized %ld clusters...\n", count);
		}
	}
	stderr.printf("Summarized %ld clusters...\n", count);
	return 0;
}
