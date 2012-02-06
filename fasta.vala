using Gee;

enum IndexParsingState { MAYBE, ID, HEADER, SEQUENCE }

class Count {

	public long val;

	public Count(long val) {

		this.val = val;

	}

}

class IndexedFasta {
	FileStream file;
	HashMap<string, Count> index;
	private IndexedFasta(owned FileStream file) {
		this.file = (owned) file;
		this.index = new HashMap<string, Count>(Gee.Functions.get_hash_func_for(typeof(string)), Gee.Functions.get_equal_func_for(typeof(string)));

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
					index[buffer.str] = new Count(this.file.tell());
					buffer.truncate();
					if (index.size % 1000000 == 0) {
						stderr.printf("Indexed %ld sequences...\n", index.size);
					}
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
		stderr.printf("Indexed %ld sequences...\n", index.size);
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
		if (file.seek(index[id].val, FileSeek.SET) != 0) {
			stderr.printf("%s %ld: %s\n", id, index[id].val, Posix.strerror(errno));
			return null;
		 }
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
