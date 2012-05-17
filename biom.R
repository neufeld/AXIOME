#In order to parse files, we need the rjson library
pkgTest <- function(x)
{
        if (!require(x,character.only = TRUE))
        {
                install.packages(x,dep=TRUE)
                if(!require(x,character.only = TRUE)) stop("Package not found")
        }
}

pkgTest("rjson")

BIOM2table <- function(filename) {


	#Read in our JSON file
	json <- fromJSON(file=filename)

	#Make an array the size that we want
	numsamples <- json$shape[2]
	numotus <- json$shape[1]

	data <- array(0, c(numotus, numsamples))

	#Parse the matrix data differently based on matrix_type property
	if ( json$matrix_type == "sparse" ) {

		for ( i in 1:length(json$data) ) {
		#Sparse matrix we have to go through each and replace each non-zero
		#entry with its value
			lst <- json$data[[i]]
			data[lst[1]+1,lst[2]+1] <- lst[3]
		}

	} else if ( json$matrix_type == "dense" ) {
			
		for ( i in 1:length(json$data) ) {
		#For a dense matrix, just grab the rows out of the JSON data field
		#and plop them into the data frame
			data[i,] <- json$data[[i]]
		}
	}

	data <- as.table(data)

	#Set the column names to the names given in each sample's id field
	samplenames <- NULL
	for ( i in 1:numsamples ) {
		samplenames <- c(samplenames, paste('X', json$columns[[i]]$id, sep=""))
	}
	colnames(data) <- samplenames

	#Set the row names to the names given in each OTU's id field
	otunames <- NULL
	for ( i in 1:numotus ) {
		otunames <- c(otunames, json$rows[[i]]$id)
	}
	rownames(data) <- otunames
	
	#Sort the data numerically, then return it transposed (so samples are the rows, OTUs the columns)
	data <- t(data[,sort.int(colnames(data))])

	return(data)
}
