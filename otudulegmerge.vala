using Gee;

int main(string[] args) {
	//We require three arguments
	if (args.length != 4) {
		stderr.printf("Usage: %s duleg_*.txt otu_table_with_sequences.txt outdir\n", args[0]);
		return 1;
	}
	//Open the Duleg text file for reading
	stderr.printf("Opening Duleg analysis...\n");
	var duleg = FileStream.open(args[1], "r");
	if (duleg == null) {
		stderr.printf("Could not open %s: %s\n", args[1], strerror(errno));
		return 1;
	}

	//Open up the otutable
	stderr.printf("Opening OTU table...\n");
	var otu = FileStream.open(args[2], "r");
	if (otu == null) {
		stderr.printf("Could not open %s: %s\n", args[2], strerror(errno));
		return 1;
	}

	var outDir = args[3];
	try {
		DirUtils.create(outDir, 0755);
	} catch (Error e) {
		stderr.printf("Error creating directory at %s\n", outDir);
	}

	//Store the otutable in a hashmap, with each of the columns items in the ArrayList<string>
	var otumap = new HashMap<int, ArrayList> ();

	//Store a hashmap that we put in the sample index, and it outputs
	//the corresponding index in the otumap ArrayList
	//This is because QIIME is stupid and orders things lexicographically, and we don't like that
	var lex2num = new HashMap<int, int> ();

	string line;
	string[] linesplit;
	//Skip the header
	if ( (line = otu.read_line()) == null ) {
		stderr.printf("Malformed OTU table, missing header line\n");
		return 1;
	}

	//Read the next line
	line = otu.read_line();
	linesplit = line.split("\t");

	//Set the hashmap that keeps track of where the sample ids have their information stored in the ArrayList
	int i = 1;
	int index;
	while ( linesplit[i] != "Consensus Lineage" ) {
		index = int.parse(linesplit[i]);
		lex2num[index] = i;
		i++;
	}

	//Read into the otumap using the species index as key
	//the values from the OTU map
	while ((line = otu.read_line()) != null) {
		linesplit = line.split("\t");
		if (linesplit.length == 0) {
			stderr.printf("Malformed line: %s\n", line);
			continue;
		}
		index = int.parse(linesplit[0]);
		var list = new ArrayList<string> ();
		//Add each of the columns of the otutable to the ist array
		for ( i = 0; i < linesplit.length; i++ ) {
			list.add(linesplit[i]);
		}
		//Add the list array to the hashmap
		otumap[index] = list;
	}

	string category;
	Regex spacekiller = null;
	//Regex for use later to filter out Duleg table info
	try {
		spacekiller = new Regex("[ ]+");
	} catch (RegexError e) {
		warning("%s", e.message);
	}

	FileStream relAbu;
	string clusterLabels;
	string[] clusterArray;

	//While duleg file is not EOF
	while ( !duleg.eof() ) {

		//Clear the category to look for next one
		category = null;
		//Clear the relAbu file where we pull cluster names from
		relAbu = null;

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
		//Take base filename, and peel off the extension
		var outString = Filename.display_basename(outName)[0:-4];
		outName = outString + "_" + category + ".tab";
		//Open the file for writing
		var outFile = FileStream.open(outDir + "/" + outName, "w");

		//Try to open the relabu.txt file to try to pull in better cluster names
		relAbu = FileStream.open(outDir + "/" + outString + "_" + category + "_relabu.txt", "r");
		if ( relAbu != null ) {
			//If the file is there, pull out only the first line
			clusterLabels = relAbu.read_line();
			//The line is formatted as a list like: " 1" "2" "3" "4" " 5" "6"
			//We first remove all spaces, then replace double quotation marks with commas, and then remove single quotations left over
			clusterLabels = clusterLabels.replace(" ","").replace("\"\"",",").replace("\"","");
			//Split the comma separated list into an array
			clusterArray = clusterLabels.split(",");
		} else {
			//If we can't open the file, set clusterArray to null to avoid complaints of it being unassigned
			clusterArray = null;
		}


		//Print output header
		outFile.printf("#OTU ID\t");

		//Print out the sample ID values in numerical order
		i = 0;
		while ( lex2num.has_key(i) ) {
			outFile.printf(i.to_string() + "\t");
			i++;
		}

		outFile.printf("Sum\tConsensus Lineage\tReprSequence\tCluster\tIndicator Value\tProbability\n");

		//Read duleg header line
		duleg.read_line();

		string delimed = null;
		string[] parts;
		int id;
		int sum;
		ArrayList<string> otuinfo;

		//While we are reading nonempty lines
		while ( (line = duleg.read_line()) != "" ) {
				if ( line.contains("0 rows") ) {
					stderr.printf("No indicator species found for %s\n", category);
					break;
				}
				if (line.contains("max.print")) {
					stderr.printf("Maximum number of indicator species (1000000) reached for category \"%s\". Some data is excluded from final output.\n",category);
					break;
				}
				//Using regex, change out any number of spaces between objects for a tab delimiter
				try {
					delimed = spacekiller.replace(line, -1, 0, "\t");
				} catch (RegexError e) {
					warning("%s", e.message);
				}
			//Split up our new string
			parts = delimed.split("\t");
			//Get the sequence id by stripping the X from it
			id = int.parse(parts[0].replace("X",""));

			//Print the information from the otumap
			if ( otumap.has_key(id) ) {
				otuinfo = otumap[id];
				outFile.printf(otuinfo[0] + "\t");
			} else {
				stderr.printf("Error: sample id %d in duleg analysis file not found in OTU table.\n", id);
				return 1;
			}

			//Print, in NUMERICAL (not stupid lexicographic) order the sample abundances
			i = 0;
			sum = 0;
			while ( lex2num.has_key(i) ) {
				outFile.printf(otuinfo[lex2num[i]] + "\t");
				sum = sum + int.parse(otuinfo[lex2num[i]]);
				i++;
			}
			var delimsplit = delimed.split("\t");
			//Print out sum column, remaining otu table info, then duleg info
			if ( relAbu != null ) {
				//If we could open the relabu.txt file, translate the cluster #'s given into their proper names
				outFile.printf("%d\t%s\t%s\t%s\t%s\t%s\n", sum, otuinfo[i+1], otuinfo[i+2], clusterArray[int.parse(delimsplit[1])-1], delimsplit[2], delimsplit[3]);
			} else {
				//Otherwise, just use the cluster numbers we are given
				outFile.printf("%d\t%s\t%s\t%s\t%s\t%s\n", sum, otuinfo[i+1], otuinfo[i+2], delimsplit[1], delimsplit[2], delimsplit[3]);

			}
		}
	}

  stderr.printf("Premature exit, malformed duleg file...\n");
  return 1;

}
