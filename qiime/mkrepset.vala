using GLib;
using Gee;

enum IndexParsingState { MAYBE, ID, HEADER, SEQUENCE }

class IndexedFasta {
	FileStream file;
	HashMap<string, long> index;
	private IndexedFasta(owned FileStream file) {
		this.file = (owned) file;
		this.index = new HashMap<string, long>(Gee.Functions.get_hash_func_for(typeof(string)), Gee.Functions.get_equal_func_for(typeof(string)));

		int v;
		IndexParsingState state = IndexParsingState.MAYBE;
		var buffer = new StringBuilder();
		while ((v = this.file.getc()) != FileStream.EOF) {
			char c = (char) v;
			switch (state) {
			case IndexParsingState.MAYBE:
				if (c == '>') {
					state = IndexParsingState.ID;
				} else if (c.isspace()) {} else {
					state = IndexParsingState.SEQUENCE;
				}
				break;
			case IndexParsingState.ID:
			case IndexParsingState.HEADER:
				if (c == '\n' || c == '\r') {
					state = IndexParsingState.SEQUENCE;
					index[buffer.str] = this.file.tell();
					buffer.truncate();
				} else if (c.isspace()) {
					state = IndexParsingState.HEADER;
				} else if (state == IndexParsingState.ID) {
					buffer.append_c(c);
				}
				break;
			case IndexParsingState.SEQUENCE:
				if (c == '\n' || c == '\r') {
					state = IndexParsingState.MAYBE;
				}
				break;
			}
		}
	}

	public static IndexedFasta ? open(string filename) {
		var file = FileStream.open(filename, "r");
		if (file == null) {
			return null;
		}
		return new IndexedFasta((owned) file);
	}

	public string ? @get(string id) {
		if (!index.has_key(id)) {
			return null;
		}
		var buffer = new StringBuilder();
		file.seek(index[id], FileSeek.SET);
		int v;
		while ((v = file.getc()) != FileStream.EOF) {
			char c = (char) v;
			if (c == '>') {
				return buffer.str;
			} else if (!c.isspace()) {
				buffer.append_c(c);
			}
		}
		return buffer.str;
	}
}

int main(string[] args) {
	stderr.printf("Opening FASTA...\n");
	var sequences = IndexedFasta.open(args[1]);
	if (sequences == null) {
		return 1;
	}
	stderr.printf("Opening Clusters...\n");
	var clusters = FileStream.open(args[2], "r");
	if (clusters == null) {
		return 1;
	}

	string line;
	while ((line = clusters.read_line()) != null) {
		var members = line.split("\t");
		if (members.length < 2) {
			continue;
		}
		var representatives = new HashMap<string, int>(Gee.Functions.get_hash_func_for(typeof(string)), Gee.Functions.get_equal_func_for(typeof(string)));
		for (var i = 1; i < members.length; i++) {
			var sequence = sequences[members[i]];
			if (sequence == null) {
				continue;
			}

			if (representatives.has_key(sequence)) {
				representatives[sequence] = representatives[sequence]+1;
			} else {
				representatives[sequence] = 1;
			}
		}

		var maxcount = 0;
		string maxsequence = "";
		foreach (var entry in representatives.entries) {
			if (entry.value > maxcount) {
				maxcount = entry.value;
				maxsequence = entry.key;
			}
		}
		stdout.printf(">%s\n%s\n", members[0], maxsequence);
	}
	return 0;
}