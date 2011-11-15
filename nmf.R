# NMF Library routines
# Copyright 2011 Xingpeng Jiang <xingpengjiang@gmail.com>
#   and Andre Masella <andre@masella.name>

# Normalize a matrix
#
# Args:
# 	m: the matix
# 	L: by rows (L=1) or columns (L=2)
# Returns:
# 	The normalized matrix
NormalizeWH <- function(m, L = 2) {
	m2 <- apply(m, L, innp <- function(x) {
			return (x / sqrt(sum(x^2)))
			})
	mtmn <- t(m2) %*% m2
	return(mtmn)
}

# Non-negative matrix factorization
#
# Args:
#		difcon: indicates how difference between the similarity matrice in two iteration.
#too small, in many times it has not convergenced in 2000 steps 
#too large, because it convergenced in 200 steps
#may try to see results on 1e-5,-6,-7,-8,-9,-10, to see if it is sensentive on convergence criteria
NMF <- function(Z, k, method = "lee", eps = 1e-16, stopconv = 40, num.iter = 2000, difcon = 1e-10, ifseed = TRUE, seed = 10) {
	n <- nrow(Z)
	m <- ncol(Z)
	# Connectivity matrix
	cons <- matrix(rep(0, m*m),ncol = m, nrow = m)
	consold <- cons
	inc <- 0

	if (min(Z) < 0) {
		stop("No negative elements allowed")
	}

	# Test if there is void data: all elements in a row are zeros.
	if(nrow(as.matrix(which(rowSums(Z) > 0))) != n) {
		stop("Zero rows are not allowed")
	}

# initiation randomly select matrix values from uniform distribution of [min(Z),max(Z)]
#set.seed()
	if (ifseed == TRUE) {
		set.seed(seed)
	}
	H <- runif(k*m, min = min(Z), max = max(Z))
	H <- matrix(H, k, m)

	if (ifseed == TRUE) {
		set.seed(seed)
	}
	W <- runif(k*n, min = min(Z), max = max(Z))
	W <- matrix(W, n, k)

	for (i in 1:num.iter){
		# Adjust small values to avoid undeflow (i.e., avoid dividing zero)
		if (i %% 10 == 0){
			maxmat <- function(x) {
				max(x, eps)
			}
			H <- apply(H, c(1,2), maxmat)
			W <- apply(W, c(1,2), maxmat)
		}

		WH1 <- W %*% H

		# Update H
		if (method == "brunet") {
			sumW <- matrix(rep(t(colSums(W)), m), k, m)
			H <- H * (t(W) %*% (Z / WH1)) / sumW
			H[is.na(H)] <- eps
		}
		if (method == "lee") {
			H <- H * ((t(W) %*% Z) / (t(W) %*% W %*% H))
			H[is.na(H)] <- eps
		}

		WH2 <- W %*% H

		# Update W  
		if (method=="brunet") {
			sumH <- matrix(rep(t(rowSums(H)), n), n, k, byrow = TRUE)
			W <- W * ((Z / WH2) %*% t(H)) / sumH
			W[is.na(H)] <- eps
		}
		if (method == "lee") {
			W <- W * ((Z %*% t(H)) / (W %*% H %*% t(H)))
			W[is.na(H)] <- eps
		}

		# Construct connectivity matrix
		cons <- NormalizeWH(H)
		difcontest <- sum((cons - consold)^2) / (m^2)
		consold <- cons
		if (is.nan(difcontest)) {
			break
		}
		if (difcontest < difcon) {
			# Connectivity matrix has not changed
			inc <- inc + 1
		} else {
			inc <- 0
		}
		if (inc > stopconv){
			break
		}
	}

	difdistance <- sum((Z - W %*% H)^2)
	if(is.na(H)) {
		print(paste("iteration = ", i , "Bad value in H matrix = ", which(is.na(H))))
	}

	if (i == num.iter) {
		print("NMF has not converged after maximum number of allowed iterations")
	}
	return(list(W = W, H = H))
}

# Find the best optimum solution for NMF give an rank K
#
# Args:
#		Z: the input matrix
#		K: the rank
#		nloop: the iterative steps
# provide one method to select W and H
# WBest and HBest means we select the factorization with the smallest KL
BestKLDiver <- function(Z, K, nloop, nmf.method = "brunet", r.nmf = FALSE, difcon = 1e-10, ifseed = FALSE) {
	n <- nrow(Z)
	m <- ncol(Z)

	Wmatrix0 <- array(0,dim=c(nloop,n,K))
	Hmatrix0 <- array(0,dim=c(nloop,K,m))

	spw0 <- rep(0,n)
	sph0 <- rep(0,m)

	SD <- rep(0,nloop)
	for (j in 1:nloop) {
		print(paste("Computing iteration", j, "of", nloop, "for rank", K))

		if (r.nmf == TRUE){
			L <- nmf(Z, K, method = nmf.method);
			W <- basis(L)
			H <- coef(L)
		} else {
			L <- NMF(Z,K,method=nmf.method,difcon=difcon,ifseed=ifseed,seed=j)
			W <- L$W
			H <- L$H
		}

		SD[j] <- sum((Z - W %*% H)^2)
		Wmatrix0[j,,] <- W
		Hmatrix0[j,,] <- H
	}

	a <- which(SD == min(SD))
	Wmatrix <- Wmatrix0[a,,]
	Hmatrix <- Hmatrix0[a,,]
	spw <- apply(Wmatrix, 1, sparseness)
	sph <- apply(Hmatrix, 2, sparseness)

	return(list(SD = SD,
		sph = sph,
		spw = spw,
		Wmatrix = Wmatrix,
		Hmatrix = Hmatrix))

}

KLDive <- function(X, WH2){
		WH2[WH2 == 0] <- 1e-300
		X[which(X == 0)] <- 1e-300
		D <- sum(X * log(X / WH2) - X + WH2)
		return(D)
}


sparseness <- function(x) {
	n <- length(x)
	sparsedegree <- (sqrt(n) - sum(abs(x)) / sqrt(sum(x^2))) / (sqrt(n) - 1)
	return(sparsedegree)
}

# Select taxa similar to a basis pfam
write.taxa.list <- function(X = An, H = H, P = P, labelnames, taxaid, pfams, pfam.file, spw1, ixv = ixv, k, simiv = 0.8, profile, V.m) {
	ix <- which(X[, k] > simiv)
	IX <- sort(X[ix, k], decreasing = TRUE, index.return = TRUE)
	ix2 <- IX$ix
	ix <- ix[ix2]
	M <- P[ix,ixv]
	M <- data.frame(taxaid = taxaid[ix], taxa = pfams[ix], similarity = X[ix, k])
	rownames(M) <- NULL
	write.table(M,con<-pfam.file)

	return(ix = ix)
}

AffineMatrix <- function(HTHN, r = 0.2){
	A <- exp(-((1 - HTHN)^2) / (2 * (r^2)))
	return(A)
}

SpectralReord <- function(HTH, method = "Lap", evrank = 1) {
	n <- nrow(HTH)
	a <- colSums(HTH)
	D <- diag(a)
	DT <- solve(D)^(1/2)
 
	if (method == "Lap") {
		L <- D - HTH
	} else {
		L <- DT %*% HTH %*% DT
	}
	eg <- eigen(L)
	Ix <- sort(eg$vectors[, n - evrank], index.return = TRUE)
	HTH2 <- HTH[Ix$ix, Ix$ix]
	diag(HTH2) <- 1
	return(list(ix = Ix$ix,
		egva = eg$values,
		ev = eg$vectors[, n - evrank],
		egv = eg$vectors,
		HTH2 = HTH2))
}

indexdiff <- function(n) {
	x <- y <- c(1:n)
	B <- matrix(0,n,n)
	for (i in 1:n) {
		for (j in 1:n) {
			B[i, j] <- abs(x[i] - y[j])
		}
	}
	return(B)
}


# Perform a spectral reordering
#
# Args:
# 	H: the matrix to reorder
# 	L: If the matrix is a W matrix, L = 1; if the matrix is an H matrix, L = 2.
spectreorder <- function(H, L, beta = c(0.01, 0.3), lim = 0.01) {
	bseq <- seq(beta[1], beta[2], lim)
	K <- length(bseq)

	HTH <- NormalizeWH(H, L)

	diag(HTH) <- 1
	n <- nrow(HTH)

	C <- rep(0, K)
	D <- rep(0, K)
	v <- matrix(0, n, K)
	evmatrix <- matrix(0, n, K)
	for (i in 1:K) {
		HTHN <- AffineMatrix(HTH, r = bseq[i])
		Slap <- SpectralReord(HTHN)
		ixv <- Slap$ix
		ev <- Slap$ev
		HTHr <- HTH[ixv, ixv]
		B <- indexdiff(n)
		C[i] <- sum(HTHr * (B^2))
		D[i] <- sum(HTHN * (B^2))
		v[,i] <- ixv
		evmatrix[, i] <- ev 
	}

	Min <- which.min(C)
	V <- v[, Min]
	ev <- evmatrix[, Min]

	HTHN <- AffineMatrix(HTH, r = bseq[Min])

	return(list(C = C,
		V = V,
		HTH = HTH[V, V],
		D = D,
		HTHN = HTHN,
		v = v,
		ev = ev))
}
rnor <- function(x) {
	x/sqrt(sum(x^2))
}

ConsensusFuzzyH <- function(Z, kstart, kend, nloop, method = "square", Rnmf = TRUE, nmf.method = "brunet", difcon = 1e-10, ifseed = FALSE) {
	n <- nrow(Z);
	m <- ncol(Z);
	# Test for negative values;
	if (min(Z) < 0) {
		stop('Some elements are negative!')
	}

	if (nrow(as.matrix(which(rowSums(Z) > 0))) != n) {
		stop('A row is all zero!')
	}
		
	KL <- rep(0, kend - 1)
	EUD <- rep(0, kend - 1)
	averdiff <- rep(0, kend - 1)

	for (j in kstart:kend) { 
		s <- 0
		t <- 0
		V <- nloop * (nloop - 1) / 2
		difference <- rep(0, V)
		connvec <- array(0, c(nloop, m, m))
		E <- rep(0, nloop)
		D <- rep(0, nloop)
		for (i in 1:nloop) {
			s <- s + 1

			if (Rnmf == TRUE) {
				if (ifseed == TRUE) {
					set.seed(i)
				}
				L <- nmf(Z, j, method = nmf.method)
				W <- basis(L)
				H <- coef(L)
			} else {
				L <- NMF(Z, j, method = nmf.method, difcon = difcon, ifseed = ifseed, seed = i)
				W <- L$W
				H <- L$H
			}

			D[i] <- KLDive(Z, W %*% H)	
			E[i] <- sum((Z - W %*% H)^2)
			connh <- NormalizeWH(H)

			connvec[i,,] <- connh

			if (s > 1) {
				for (k in 1:(s - 1)){
					if (method == "abs") {
						a <- sum(abs(connh-connvec[k,,]))
					} else if (method == "square") {
						a <- sum((connh - connvec[k, , ])^2)
					}
					t <- t + 1
					difference[t] <- a
				}
			}
		}
		KL[j - 1] <- sum(D[i]) / nloop
		EUD[j - 1] <- sum(E[i]) / nloop
		averdiff[j - 1] <- 1 - sum(difference) / (V * (m^2))
	}

	return(list(averdiff = averdiff,
				KL = KL,
				EUD = EUD))
}

# Plot a matrix by labeling columns and rows
nmfplot <- function(OrdZ, taxa, samples, colorset = 12, op = par(mar = c(10, 2, 4, 8)), shown = 100, colorf = heat.colors, cexaxis = 0.7, cexayis = 0.7) {
	#nrowZ: the number of rows of Z for visulization
	nrowZ <- nrow(OrdZ)
	zmin <- min(OrdZ)
	zmax <- max(OrdZ)

	yLabels <- taxa
	xLabels <- samples

	ColorRamp <-colorf(colorset);
	ColorLevels <- seq(zmin, zmax, length = length(ColorRamp))

	# Reverse Y axis
	reverse <- c(nrowZ:1)
	yLabels <- yLabels[reverse]
	OrdZ <- OrdZ[reverse,]
	op <- op

	image(1:length(xLabels), 
		1:length(yLabels), 
		t(OrdZ), 
		col = ColorRamp,
		xlab = "", ylab = "", 
		axes = FALSE, 
		zlim = c(zmin, zmax),
		font.axis = 2)

	axis(BELOW <- 1, 
		at = 1:length(xLabels),
		las = 2, 
		labels = xLabels, 
		cex.axis = cexaxis)

	if (nrowZ < shown) { 
		axis(LEFT <- 4,
			at = 1:length(yLabels),
			labels = yLabels,
			las = HORIZONTAL <- 1,
			pos<-3,
			cex.axis = cexayis)
	}
	par(op)
	layout(1)
}

image <- function(x, ...) UseMethod("image")

image.default <- function (
	x = seq(0, 1, length.out = nrow(z)),
	y = seq(0, 1, length.out = ncol(z)),
	z,
	zlim = range(z[is.finite(z)]),
	xlim = range(x),
	ylim = range(y),
	col = heat.colors(12), add = FALSE,
	xaxs = "i", yaxs = "i", xlab, ylab,
	breaks, oldstyle=FALSE, 
	useRaster = FALSE, ...) {
	if (missing(z)) {
		if (!missing(x)) {
			if (is.list(x)) {
				z <- x$z; y <- x$y; x <- x$x
			} else {
				if(is.null(dim(x)))
					stop("argument must be matrix-like")
						z <- x
						x <- seq.int(0, 1, length.out = nrow(z))
			}
			if (missing(xlab)) xlab <- ""
				if (missing(ylab)) ylab <- ""
		} else stop("no 'z' matrix specified")
	} else if (is.list(x)) {
		xn <- deparse(substitute(x))
			if (missing(xlab)) xlab <- paste(xn, "x", sep = "$")
				if (missing(ylab)) ylab <- paste(xn, "y", sep = "$")
					y <- x$y
						x <- x$x
	} else {
		if (missing(xlab))
			xlab <- if (missing(x)) "" else deparse(substitute(x))
				if (missing(ylab))
					ylab <- if (missing(y)) "" else deparse(substitute(y))
	}
	if (any(!is.finite(x)) || any(!is.finite(y)))
		stop("'x' and 'y' values must be finite and non-missing")
			if (any(diff(x) <= 0) || any(diff(y) <= 0))
				stop("increasing 'x' and 'y' values expected")
					if (!is.matrix(z))
						stop("'z' must be a matrix")
							if (length(x) > 1 && length(x) == nrow(z)) { # midpoints
								dx <- 0.5*diff(x)
									x <- c(x[1L] - dx[1L], x[-length(x)]+dx,
											x[length(x)]+dx[length(x)-1])
							}
	if (length(y) > 1 && length(y) == ncol(z)) { # midpoints
		dy <- 0.5*diff(y)
			y <- c(y[1L] - dy[1L], y[-length(y)]+dy,
					y[length(y)]+dy[length(y)-1])
	}

	if (missing(breaks)) {
		nc <- length(col)
			if (!missing(zlim) && (any(!is.finite(zlim)) || diff(zlim) < 0))
				stop("invalid z limits")
					if (diff(zlim) == 0)
						zlim <- if (zlim[1L] == 0) c(-1, 1)
					else zlim[1L] + c(-.4, .4)*abs(zlim[1L])
						z <- (z - zlim[1L])/diff(zlim)
							zi <- if (oldstyle) floor((nc - 1) * z + 0.5)
			else floor((nc - 1e-5) * z + 1e-7)
				zi[zi < 0 | zi >= nc] <- NA
	} else {
		if (length(breaks) != length(col) + 1)
			stop("must have one more break than colour")
				if (any(!is.finite(breaks)))
					stop("breaks must all be finite")
						zi <- .C("bincode",
								as.double(z), length(z), as.double(breaks), length(breaks),
								code = integer(length(z)), (TRUE), (TRUE), nok = TRUE,
								NAOK = TRUE, DUP = FALSE, PACKAGE = "base") $code - 1
	}
	if (!add)
		plot(NA, NA, xlim = xlim, ylim = ylim, type = "n", xaxs = xaxs,
				yaxs = yaxs, xlab = xlab, ylab = ylab, ...)
## need plot set up before we do this
			if (length(x) <= 1) x <- par("usr")[1L:2]
				if (length(y) <= 1) y <- par("usr")[3:4]
					if (length(x) != nrow(z)+1 || length(y) != ncol(z)+1)
						stop("dimensions of z are not length(x)(-1) times length(y)(-1)")
							if (useRaster) {
# check that the grid is regular
								dx <- diff(x)
									dy <- diff(y)
									if ((length(dx) && !isTRUE(all.equal(dx, rep(dx[1], length(dx))))) ||
											(length(dy) && !isTRUE(all.equal(dy, rep(dy[1], length(dy))))))
										stop("useRaster=TRUE can only be used with a regular grid")
# this should be mostly equivalent to RGBpar3 with bg=NA
											if (!is.character(col)) {
												p <- palette()
													pl <- length(p)
													col <- as.integer(col)
													col[col < 1L] <- NA_integer_
													col <- p[((col - 1L) %% pl) + 1L]
											}
								zc <- col[zi + 1L]
									dim(zc) <- dim(z)
									zc <- t(zc)[ncol(zc):1L,]
																			 rasterImage(as.raster(zc),
																					 min(x), min(y), max(x), max(y),
																					 interpolate=FALSE)
							} else .Internal(image(as.double(x), as.double(y), as.integer(zi), col))
}

nmfplot.h <- function(OrdZ, taxa, samples, colorset = 100, colorf = heat.colors, cexaxisx = 0.7, cexaxisy = 0.7){
	nrowZ<-nrow(OrdZ)
	zmin <- min(OrdZ)
	zmax <- max(OrdZ)

	yLabels <- taxa
	xLabels <- samples

	ColorRamp <- colorf(colorset);
	ColorLevels <- seq(zmin, zmax, length = length(ColorRamp))

	layout(matrix(data = c(1, 2), nrow = 1, ncol = 2), widths = c(4, 1), heights = c(1, 2.3))

# Reverse Y axis
	reverse <- c(nrowZ:1)
	yLabels <- yLabels[reverse]
	OrdZ <- OrdZ[reverse, ]

	image(1:length(xLabels), 1:length(yLabels), t(OrdZ), col = ColorRamp, xlab = "", ylab = "", axes = FALSE, zlim = c(zmin, zmax), font.axis = 2 , useRaster = TRUE)
	axis(BELOW<-1, at = 1:length(xLabels), las = 2, labels = xLabels, cex.axis = cexaxisx)
	if (nrowZ < 250) {
		axis(LEFT <-4, at = 1:length(yLabels), labels = yLabels, las = HORIZONTAL <- 1, pos <- 3, cex.axis = cexaxisy)
	}

	op2 <- par(mar = c(10, 4.5, 10, 2))
	# Color Scale
	image(1, ColorLevels, matrix(data = ColorLevels, ncol = length(ColorLevels), nrow = 1), col = ColorRamp, xlab = "", ylab = "", xaxt = "n", useRaster = FALSE)
}


