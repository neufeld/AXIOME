
class NumericFileIterator {
	private FileStream stream;
	private string line;
	private long num;
	public string Line {get {return line;}}
	public long Value {get {return num;}}

	public static NumericFileIterator? open(string filename) {
		var stream = FileStream.open(filename, "r");
		if (stream == null) {
			return null;
		} else {
			return new NumericFileIterator((owned) stream);
		}
	}
	private NumericFileIterator(owned FileStream stream) {
		this.stream = (owned) stream;
	}

	public bool next() {
		if (stream.eof()) {
			return false;
		}
		line = stream.read_line();
		num = long.parse(line);
		return true;
	}
}

int main(string[] args) {
	var left = NumericFileIterator.open(args[1]);
	var right = NumericFileIterator.open(args[2]);

	if (!left.next() || !right.next())
		return 0;

	while(true) {
		if (left.Value == right.Value) {
			stdout.printf("%s\t%s\n", left.Line, right.Line);
			if (!left.next()) {
				return 0;
			}
			if (!right.next()) {
				return 0;
			}
		} else if (left.Value < right.Value) {
			if (!left.next()) {
				return 0;
			}
		} else {
			if (!right.next()) {
				return 0;
			}
		}
	}
}
