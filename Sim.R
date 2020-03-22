## simulating returns of test assets and factors

## for applications to double selection lasso approach



library("mvtnorm")

library("pracma")

library("MASS")


# set dimensions

n <- 100 # Number of assets

p <- 25

T <- 240

d <- 3


# Load tune center

tune_center <- matrix(c(0.000000018,  1.8e-8, 1.8e-8, 1.80E-08, 1.80E-08, 1.80E-08, 1.80E-08,  1.80E-08, 1.80E-08,  1.80E-08,  1.80E-08, 1.80E-08, 1.80E-08, 1.80E-08,  1.80E-08, 0.00000000000176,4.30E-13, 8.11E-12, 3.25E-11,6.28E-12, 2.94E-11 
                        , 2.07E-12, 2.44E-11, 8.23E-12,1.01E-12,1.42E-12
                        , 2.45E-11, 2.52E-12, 2.44E-10, 7.04E-11  ), nrow=15, ncol =2)


# must calibrate parameters using Fama-French 5 factors:

# calibrate: chi, eta, lambda, Sigmaz, Ce, Ch1, and Sigmah

temp3 = cov(cbind(allfactors[c("MktRf","HML", "SMB", "UMD", "cash", "HML_Devil", "gma")], Ri))
Ch1 = temp3[8: 107, 1:4]
Ce = temp3[8:107, 5:7]

#mean_Ce  <- as.matrix(rep(0,d))

#cov_Ce   <- diag(rep(1,d))

#mean_Ch1 <- as.matrix(rep(0,4))

#cov_Ch1   <- diag(rep(1,4))


set.seed(69) # for reproducability

# (1) simulate Ce (nxd) and Ch1 (nx4) independently from multivariate normals

#Ce  <- mvrnorm(n, mean_Ce, cov_Ce)

#Ch1 <- mvrnorm(n, mean_Ch1, cov_Ch1)



# (2) calculate Ch2, initialize theta0 (p-4)x1, theta1 (p-4)x4, and Ceps nx(p-4) ~ N(m,S) 

theta0 <- matrix(1, nrow = p-4, ncol = 1) # Using a matrix of ones
theta1 <- matrix(1, nrow = p-4, ncol = 4)

mean_Ceps  <- as.matrix(rep(0,p-4))

cov_Ceps   <- diag(rep(1,p-4))

Ceps   <-  mvrnorm(n, mean_Ceps, cov_Ceps)

Ch2    <- matrix(1, nrow = n, ncol = 1) %*% t(theta0) + Ch1 %*% t(theta1) + Ceps



# (3) Cg

#xi  <- matrix(1, nrow = 1, ncol = d)

#chi <- matrix(0, nrow = d, ncol = p)

Ch  <- cbind(Ch1, Ch2)  # (nxp)

xi = t(matrix(cbind(as.matrix(1), t(as.matrix(rep(0,d-1)))), nrow = d, ncol = 1)) # no loadings on redundant factors
chi = t(rbind(matrix(1, nrow = 4, ncol = d), matrix(0, nrow = (p-4), ncol = d)))

Cg  <- matrix(1, nrow = n, ncol = 1) %*% xi + Ch %*% t(chi) + Ce  # Cg ~ (nxd)



# (4) Cz

#eta <- matrix(0, nrow = d, ncol = p)

eta = rbind(matrix(1, nrow= 1, ncol = p), matrix(0, nrow = 2, ncol = p)) # Calibrated to ensure 0 loadings of gt on h1t

Cz  <- Cg - Ch %*% t(eta) # (nxd) - (nxp)(pxd) 



# (5) Er

gamma0  <- matrix(1, nrow = 1, ncol =1)

lambdag <- matrix(c(1,0,0), nrow = 3, ncol = 1)  # one useful g, one useless, one redundant

lambdah <- rbind(matrix(c(1,1,1,1),nrow = 4, ncol = 1), matrix(0, nrow = p-4, ncol = 1)) # 4 useful h, p-4 useless

Ert  <- matrix(1, nrow = n, ncol = 1) %*% gamma0 + Cg %*% lambdag + Ch %*% lambdah



# (6) calculate betas

#Sigmaz <- matrix(1,nrow = d, ncol = d)

Sigmaz = diag(rep(1,d))
Sigmah = diag(rep(1,p))

Betag  <- Cz %*% inv(Sigmaz) # (nxd)(dxd)  #use pracma for inverse!!

#Sigmah <- matrix(1,nrow = p, ncol = p) 

Betah  <- Ch %*% inv(Sigmah) # (nxp)(pxp)




# Monte Carlo Simulations (Repeat 2000 times)

Sigmau <- matrix(1,nrow = n, ncol = n)   #variance of sigmau disturbances


Rt = matrix(nrow = 100)
Ht = matrix(ncol = p)
Gt = matrix(ncol = d)

# Draw T data points to create dataset 
for (i in 1:T){


  ut     <- dt(sample(1:1000, n, replace = TRUE)/1000,df = 5) #??    # draw (nx1) ut from student t distribution with 5 deg of freedom and Sigmau var
  
  
  # (7) generate ht, zt -- >
  
  mean_ht  <- as.matrix(rep(0,p))
  
  ht  <- as.matrix(mvrnorm(1, mean_ht, Sigmah)) 
  #ht = t(temp2)                        
  
  mean_zt <- as.matrix(rep(0,d))
  
  zt <- as.matrix(mvrnorm(1, mean_zt, Sigmaz))
  
  gt <- as.matrix(eta)%*%as.matrix(ht) + zt
  
  rt     <- Ert + Betag %*% gt + Betah %*% ht  + as.matrix(ut)
  
  Rt = cbind(Rt, rt)
  Ht = rbind(Ht, t(ht))
  Gt = rbind(Gt, t(gt))

}
          
Rt = Rt[, 2:ncol(Rt)]
Ht = Ht[2:nrow(Ht),]
Gt = Gt[2:nrow(Gt),]


# Enter data in DS model:

model_ds  <- DS(Rt, t(Gt), t(Ht), -log(tune_center[1,1]), -log(tune_center[1,2]),1,seed_num)

tstat_ds  <- model_ds$lambdag_ds/model_ds$se_ds

lambda_ds <- model_ds$gamma_ds

result <- data.frame(matrix(0,nrow = length(TestList),ncol = 10))

names(result) <- c("tstat_ds", "lambda_ds", "tstat_ss", "lambda_ss", "avg", "tstat_avg",
                   
                   "lambda_ols", "tstat_ols", "lambda_FF3", "tstat_FF3")

result$tstat_ds[1]   <- tstat_ds

result$lambda_ds[1]  <- lambda_ds