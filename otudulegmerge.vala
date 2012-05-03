using Gee;

int main(string[] args) {
	//We require two arguments
	if (args.length != 3) {
		stderr.printf("Usage: %s duleg_*.txt otu_table_with_sequences.txt\n", args[0]);
		return 1;
	}
	//Open the Duleg text file for reading
	stderr.printf("Opening Duleg analysis...\n");
	var duleg = FileStream.open(args[1], "r");
	if (duleg == null) {
		stderr.printf("Could not open %s: %s\n", args[1], strerror(errno));
		return 1;
	}

	var map = new HashMap<string, string> ();
	string line;
	string category;

	// While duleg file is not EOF
	while ( !duleg.eof() ) {

		//Clear the map (necessary for each category)
		map.clear();
		category = null;

		//Search for a category
		while (category == null) {
			line = duleg.read_line();
			//If we hit EOF while looking for a category, we're done
			if ( duleg.eof() ) {
				stderr.printf("Done!\n");
				return 0;
			}

			//Check if this is our category line
			if (line.contains("[1] \"For")) {
				//Grab the category string out of the line
				category = line.slice(line.index_of("\"")+5, line.last_index_of("\""));
			}
		}

		//Set up the output filename
		string outName = args[1];
		outName = outName + "_" + category + ".tab";
		//Open the file for writing
		var outFile = FileStream.open(outName, "w");

		//Read header line
		duleg.read_line();

		string delimed = null;
		string[] parts;
		string id;

		//While we are reading nonempty lines
		while ( (line = duleg.read_line()) != "" ) {
			try {
				//Using regex, change out any number of spaces between objects for a semicolon delimiter
				var spacekiller = new Regex("[ ]+");
				delimed = spacekiller.replace(line, -1, 0, ";");
			} catch (RegexError e) {
				warning("%s", e.message);
			}
			//Split up our new string
			parts = delimed.split(";");
			//Get the sequence id by stripping the X from it
			id = parts[0].replace("X","");
			//For each sequence id, store the duleg information in a ; delimited string
			map.set(id, delimed.splice(0,delimed.index_of(";")+1));

		}

		//Open up the otutable (done once for each category)
		var otu = FileStream.open(args[2], "r");
		if (otu == null) {
			stderr.printf("Could not open %s: %s\n", args[2], strerror(errno));
			return 1;
		}

		//Skip the header
		otu.read_line();
		//Read the next line
		line = otu.read_line();

		//Output the line same as it was, but add duleg info
		outFile.printf("%s\tCluster\tIndicatorValue\tProbability\n", line);

		string duleginfo;
		string[] duleginfoarray;

		//For each line in the otutable, if we find the sequence in our duleg
		//indicator species results, then print corresponding duleg info and
		//otu table info to our new outfile
		while ((line = otu.read_line()) != null) {
			parts = line.split("\t");
			if (parts.length == 0) {
				stderr.printf("Malformed line: %s\n", line);
				continue;
			}

			if (map.has_key(parts[0])) {
				duleginfo = map.get(parts[0]);
				duleginfoarray = duleginfo.split(";");
				outFile.printf("%s\t%s\t%s\t%s\n", line, duleginfoarray[0], duleginfoarray[1], duleginfoarray[2]);
			}
		  }
	  }

	  stderr.printf("Premature exit, malformed duleg file...\n");
	  return 1;
  }