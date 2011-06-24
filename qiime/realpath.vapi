namespace RealPath {
	[CCode(cname="realpath",cheader_filename="stdlib.h")]
	extern string realpath(string path, [CCode (array_length = false, null_terminated = true)] char[]? buffer = null);
}
