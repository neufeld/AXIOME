int main(string[] args) {
	if (args.length != 4) {
		stderr.printf("Usage: %s otu_table.txt mapping.txt column\nReitle the columns of the OTU table given the column name in mapping.txt.\n", args[0]);
		return 1;
	}

	var mapping = FileStream.open(args[2], "r");
	if (mapping == null) {
		stderr.printf("%s: cannot open\n", args[2]);
		return 1;
	}
	var str = mapping.read_line();
	if (str == null) {
		stderr.printf("Mapping file is empty!\n");
		return 1;
	}
	var index = -1;
	var parts = str.split("\t");
	for(var it = 0; it < parts.length; it++) {
		if (parts[it] == args[3]) {
			index = it;
			break;
		}
	}

	if (index == -1) {
		stderr.printf("Could not find column \"%s\".\n", args[3]);
		return 1;
	}

	var names = new Gee.HashMap<string, string>();
	while((str = mapping.read_line()) != null) {
		parts = str.split("\t");
		if (index >= parts.length) {
			stderr.printf("Mangled line has only %d column.\n", parts.length);
		}
		names[parts[0]] = parts[index];
	}
	var table = FileStream.open(args[1], "r");
	if (table == null) {
		stderr.printf("%s: cannot open\n", args[1]);
		return 1;
	}

	str = table.read_line();
	if (str == null) {
		stderr.printf("OTU table is empty!\n");
		return 1;
	}
	stdout.puts(str);
	stdout.putc('\n');
	str = table.read_line();
	if (str == null) {
		stderr.printf("OTU table is almost empty!\n");
		return 1;
	}
	parts = str.split("\t");
	for (var it = 0; it < parts.length; it++) {
		stdout.printf("%s%c", names.has_key(parts[it]) ? names[parts[it]] : parts[it], it == parts.length - 1 ? '\n' : '\t');
	}

	var buffer = new uint8[1024];
	int orig = buffer.length;
	size_t size;
	while((size = table.read(buffer)) > 0) {
		buffer.length = (int) size;
		stdout.write(buffer);
		buffer.length = orig;
	}
	return 0;
}

