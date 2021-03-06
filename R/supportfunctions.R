
########################
##function CrWholeMat
##Input: scalar response Y
##       multiple functional process list X
##		 Recorded timePoint tPoint
##		 FPCA settings options
##Output:  Returnlist: a list consists of 
##						FPCAlist: a list of the FPCA results of each X
##						CrMat: The whole Covariance matrix of list X
##						CrMatYZ: a list of the cross covariance matrices of X,Y 
########################
CrWholeMat<-function(Y,X,tPoint,options){
	nsubj = length(X)
	##doing FPCA separately
		for(i in 1:nsubj){
			assign( paste0("PCARes_",i),FPCA(X[[i]],tPoint[[i]],options[[i]]) )
		}
		##choose CrMat size baseon dataType
		TPlength = length( get(paste0("PCARes_",1))$workGrid)
		CrMat = matrix(0,nsubj*TPlength,nsubj*TPlength)
		## fill in the holes
		for (i in 1:nsubj) {
			tmp = ((i-1)*TPlength+1) : (i*TPlength)
			CrMat[tmp,tmp] = get(paste0("PCARes_",i))$fittedCov
		}
		##calculate the cross cov
		for(i in 1:nsubj){
			for(j in (i):nsubj){
				if(i!=j){
					if( (options[[i]]$dataType == "Dense")& (options[[j]]$dataType == "Dense") ){
						PCARes_A = get(paste0("PCARes_",i))
						PCARes_B = get(paste0("PCARes_",j))
						CrCovBlock = cov(matrix(unlist(X[[i]]), ncol = length(X[[i]][[1]]), byrow = TRUE),
										matrix(unlist(X[[j]]), ncol = length(X[[j]][[1]]), byrow = TRUE))
						tmp_row = ((i-1)*TPlength+1) : (i*TPlength)
						tmp_col = ((j-1)*TPlength+1) : (j*TPlength)
						if(ncol(CrCovBlock)!= TPlength){
							CrCovBlock = matrix(interp2lin(xin = tPoint[[i]][[1]],yin = tPoint[[i]][[1]],zin = CrCovBlock,xou = expand.grid(PCARes_1$workGrid,PCARes_1$workGrid)$Var1,you = expand.grid(PCARes_1$workGrid,PCARes_1$workGrid)$Var2 ),TPlength,TPlength)
						}
						CrMat[tmp_row,tmp_col] = CrCovBlock
						CrMat[tmp_col,tmp_row] = t(CrCovBlock)
					}else if((options[[i]]$dataType == "Sparse")& (options[[j]]$dataType == "Sparse") ){
						PCARes_A = get(paste0("PCARes_",i))
						PCARes_B = get(paste0("PCARes_",j))
						CrCovBlock = GetCrCovYX(bw1 = 0.1, Ly1 = X[[i]], Lt1 = tPoint[[i]],
					 				Ymu1 = approx(x = PCARes_A$workGrid,y = PCARes_A$mu,xout = sort(unique(unlist(tPoint[[i]]))),rule = 2 )$y
					 				, bw2 = 0.1, Ly2 = X[[j]],
				  	 				Lt2 = tPoint[[j]], 
				  	 				Ymu2 =approx(x = PCARes_B$workGrid,y = PCARes_B$mu,xout = sort(unique(unlist(tPoint[[j]]))),rule = 2 )$y)
						tmp_row = ((i-1)*TPlength+1) : (i*TPlength)
						tmp_col = ((j-1)*TPlength+1) : (j*TPlength)
						CrMat[tmp_row,tmp_col] = CrCovBlock$smoothedCC
						CrMat[tmp_col,tmp_row] = t(CrCovBlock$smoothedCC)
					}else{
						PCARes_A = get(paste0("PCARes_",i))
						PCARes_B = get(paste0("PCARes_",j))
						XA = PCARes_A$xiEst%*%t(PCARes_A$phi) 
						XB =  PCARes_B$xiEst%*% t(PCARes_B$phi)
						CrCovBlock = cov(XA,XB)
						tmp_row = ((i-1)*TPlength+1) : (i*TPlength)
						tmp_col = ((j-1)*TPlength+1) : (j*TPlength)
						CrMat[tmp_row,tmp_col] = CrCovBlock
						CrMat[tmp_col,tmp_row] = t(CrCovBlock)
					}
				}
			}
		}
		##return FPCA result and covMat
		FPCAlist = list()
		for(i in 1:nsubj){
			FPCAlist = append(FPCAlist,list(get(paste0("PCARes_",i))) )
		}
		CrMatYZ = list()
		for(i in 1:nsubj){
			if(options[[1]]$dataType == "Dense"){
				##under dense case, directly use matrix calculation
				g_hat = 0
				for(j in 1:length(Y)){
		  			g_hat = g_hat+(Y[j]-mean(Y))*(X[[i]][[j]])/length(Y)
				}
				if(length(g_hat) != length(PCARes_1$workGrid) ){g_hat = approx(x = tPoint[[i]][[1]],y = g_hat,xout = PCARes_1$workGrid,rule = 2)$y}
				CrMatYZ = append(CrMatYZ,list( g_hat ) )
				## warning: if X have missing values involved or not observed on same time point for different curves
				## our method cannot be used here.
			}else if(options[[1]]$dataType == "Sparse"){
				##under sparse case
				mu_imputed = approx(x = get(paste0("PCARes_",i))$workGrid,y = get(paste0("PCARes_",i))$mu,xout = sort(unique(unlist(tPoint))),rule = 2)$y
				CrCovInfo = GetCrCovYZ(bw = 0.1, Y, Zmu = mean(Y), X[[i]], Lt = tPoint[[i]], Ymu = mu_imputed,
							support = get(paste0("PCARes_",i))$workGrid,kern = "gauss")
				CrMatYZ = append(CrMatYZ,list( CrCovInfo$smoothedCC ) )
			}
		}
		##adjust diag
		Returnlist = list(FPCAlist,CrMat,CrMatYZ)
		names(Returnlist) = c("FPCAlist","MultiCrXY","MultiCrYZ")
		return(Returnlist)	
}


##############################################
##integrate a dense data on certain interval,trival version
# f: value of function to be int on timepoint tp
# tp:time point
# interval
FakeInt<-function(f,tp,interval){
	n = length(tp)
	Block = rep(0,n)
	sum = 0
	for(i in 1:n ){
		if(i == 1){
		Block[i] = tp[i] -  interval[1]	
		sum = sum + f[i]*Block[i]/2
		}
		else{
			Block[i] = tp[i]-tp[i-1]
		sum = sum + (f[i]+f[i-1])*Block[i]/2
		}
	}
	sum = sum + f[n]*(interval[2]-tp[n])/2
 sum
}

##############################################
##Calculate the prediction scores
# v: the curve to be predicted, a list
# tp: the timepoint of predited curve, a list corresponding to v
# MatrixInfo: the info list get from function CrWholeMat
# Lambda: eigen value,vector
# Phi: eigen function, matrix form

GetCE_Mul<-function(v,tp,MatrixInfo,Lambda,Phi){
	p = length(v)
	TP = MatrixInfo$FPCAlist[[1]]$workGrid
	TPlength = length(TP)
	Sigma = MatrixInfo$MultiCrXY
	tplength = length(unlist(tp))
	tpBlock = cumsum(unlist(lapply(tp,length)))
	SigmaU = matrix(0,tplength,tplength)
	for(i in 1:p){
		for(j in (i):p){
			if(i == j){
				tmp = ((i-1)*TPlength+1) : (i*TPlength)
				if(i == 1){
					blk = 1:tpBlock[1]
					}else{
					blk = (tpBlock[i-1]+1):tpBlock[i]
					}
				Grid1 = expand.grid(TP,TP)
				Grid2 = expand.grid(tp[[i]],tp[[i]])
				SigmaU[blk,blk]  = matrix(interp2lin(xin = TP,yin =TP ,zin = Sigma[tmp,tmp],xou = Grid2$Var1,you = Grid2$Var2),nrow = length(blk)) + MatrixInfo$FPCAlist[[i]]$sigma2 *diag(length(blk))
			}else{
				tmp_row = ((i-1)*TPlength+1) : (i*TPlength)
				tmp_col = ((j-1)*TPlength+1) : (j*TPlength)
				if(i == 1){
					blk_row = 1:tpBlock[1]
					}else{
					blk_row = (tpBlock[i-1]+1):tpBlock[i]
					}
				if(j == 1){
					blk_col = 1:tpBlock[1]
					}else{
					blk_col = (tpBlock[j-1]+1):tpBlock[j]
					}
				Grid2 = expand.grid(tp[[i]],tp[[j]])
				SigmaU[blk_row,blk_col] = matrix(interp2lin(xin = TP,yin = TP,zin = Sigma[tmp_row,tmp_col],xou = Grid2$Var1,you = Grid2$Var2), nrow = length(blk_row))
				SigmaU[blk_col,blk_row] = t(SigmaU[blk_row,blk_col])
			}
		}
	}
	Mu = rep(0,tplength)
	L = ncol(Phi)
	Phi_P = matrix(0,tplength,L)
	for(i in 1:p){
		if(i == 1){
					blk = 1:tpBlock[1]
			}else{
					blk = (tpBlock[i-1]+1):tpBlock[i]
		}
		Mu[blk] = approx(x = TP ,y = MatrixInfo$FPCAlist[[i]]$mu,xout = tp[[i]], rule = 2 )$y
		tmp = ((i-1)*TPlength+1) : (i*TPlength)
		for(j in 1:L){
			Phi_P[blk,j] = approx(x = TP ,y = Phi[tmp,j] ,xout = tp[[i]], rule = 2 )$y	
		}	
	}
	score = Lambda * t(Phi_P) %*% ginv(SigmaU) %*% (unlist(v) - Mu)
	return(score)
}


#lapply(varsPred,function(x){x$Ly[[1]]})









