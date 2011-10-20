namespace Files {
	Gee.HashMap<string, FileWrapper> map;
	class FileWrapper : Object {
		public FileStream stream;
	}
	public void init() {
		map = new Gee.HashMap<string, FileWrapper>();
	}

	public void put(string s, owned FileStream fs) {
		map[s] = new FileWrapper() { stream = (owned) fs};
	}

	[PrintfFormat]
	public bool write(string s, string format, ...) {
		if (map.has_key(s)) {
			var va = va_list();
			map[s].stream.vprintf(format, va);
			return true;
		} else {
			return false;
		}
	}

	public void finish() {
		map = null;
	}
}
