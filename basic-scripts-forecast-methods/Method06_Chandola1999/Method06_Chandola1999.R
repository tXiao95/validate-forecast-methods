#######################################################################
#######################################################################
## 'validate-forecast-methods' is a program that provides the R source code
## used for the calculations in the project: 
## Bohk-Ewald, Christina, Peng Li, and Mikko Myrskylä (2017). 
## Assessing the accuracy of cohort fertility forecasts. 
## Presented in session: Statistical methods in demography 
## at the PAA 2017 Annual Meeting, Chicago, IL, USA, April 27-April 29, 2017. 
## (c) Copyright 2018, Christina Bohk-Ewald, Peng Li, Mikko Myrskylä

## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.

## You should have received a copy of the GNU General Public License
## along with this program (see LICENSE.txt in the root of this source code).
## If not, see <http://www.gnu.org/licenses/>.
#######################################################################
#######################################################################

###############################################################################
#    Project: Cohort fertility forecastes and their accuracy
#    CBE, PL and MM
#    2017.05.19
#    
#    Method:   
#    Method06_Chandola1999.R
############################################################
#### Input file: 
#     ASFR: age-specific fertility rate
#     
#     
#### Parameters
#      joy: jump of year
#      obs: length of observation
#      age1 : star age
#      age2 : end age
#      parameter : parameter of the method
#                projection method of parameters [original/arima/freezed]
#                arima: max ordre of (p,d,q) is (5,2,2) using auto.arima
#                freezed: use the last observed parameter (alpha, beta) 
#      len : length of forecasting period
#      pop : population
#### Output: 
#      obsASFR: observed ASFR, age * period
#      obsCASFR: observed ASFR, age * cohort
#      predASFR: forecasted ASFR, age * period
#      predCASFR: forecasted ASFR, age * cohort
#      method: name of the method
#      parameter: parameter of the method
#      year: starting year of observed period, JOY and last year of forecasting
#      age: range of age
#      obs: number of years of observation
#      len: forecasting length
#      cohort: c1: oldest cohort at the starting year of observation
#              c2: youngest cohort at the starting year of observation
#              c3: oldest cohort at JOY
#              c4: youngest cohort at JOY
#### NOTE:
#      
#### Ref:
#   1. Chandola T, Coleman DA, Hiorns RW (1999) Recent European fertility patterns: Fitting
#      curves to "'distorted'" distributions. Population Studies 53(3):317-329.
#       
#       
###############################################################################
library(forecast)
##############################################################################
# Chandola 1999 method
################################ 
Chandola_fx <- function(par,x){
  alpha <- par[1]
  m <- par[2]
  b1 <- par[3]
  c1 <- par[4]
  b2 <- par[5]
  c2 <- par[6]
  fx <- alpha*m*(b1/c1)*(c1/x)^(1.5)*exp(-(b1^2)*((c1/x)+(x/c1)-2))+(1-m)*(b2/c2)*(c2/x)^(1.5)*exp(-(b2^2)*((c2/x)+(x/c2)-2))
  names(fx) <- x
  return(fx)
}

Fit_Chandola_fx <- function(par,data,method,x){
  fctn_Chandola <- function(par, data){
    res <- sum((data - Chandola_fx(par,x))^2)
    return(res)
  }
  fit <- optim(par,fctn_Chandola,gr=NULL,data,method=method,control=list(trace=F)) 
  return(fit$par)
}

if(0>1){
  aut.complete = ASFR[,"2014"]
  fitChandola.complete <- Fit_Chandola_fx(par=c(2,0.5,1,26,1,26),data=aut.complete,x=15:44,method="Nelder-Mead") 
  fitChandola.complete 
  
  plot(x=15:44,y=aut.complete,col="red")
  lines(x=15:44,y=Chandola_fx(fitChandola.complete,15:44),col="red")
}

###########################################
Method06_Chandola1999.R <- function(ASFR,
                                    joy = 1985, 
                                    obs = 30,
                                    age1 = 15, 
                                    age2 = 44,
                                    parameter = c("original"),
                                    len = 30,
                                    pop=""
){
  
  ################ Data step
  if(is.na(joy))
    joy <- max(as.numeric(colnames(ASFR)[!is.na(apply(ASFR,2,sum))]))
  ########
  year1 <- joy - obs + 1
  year2 <- joy
  year3 <- year2 + len
  ########
  # extract input data
  fert.raw <- ASFR[paste(age1:age2),paste(year1:year2)]
  fert.raw[fert.raw<=0.00001] <- 0.00001
  raw.data <- matrix(NA,nrow=nrow(fert.raw),ncol=(year3-year1+1))
  colnames(raw.data) <- paste(year1 + c(1:ncol(raw.data))-1)
  rownames(raw.data) <- rownames(fert.raw)
  raw.data[,colnames(fert.raw)] <- fert.raw
  
  ########
  if(any(is.na(sum(raw.data[,paste(c(year1,year2))]))))
    return(list(pop=pop,
                obsASFR=ASFR,
                obsCASFR=asfr_period_to_cohort(ASFR),
                predASFR=NA,
                predCASFR=NA,
                method="Chandola (1999)",
                parameter=parameter,
                label=ifelse(all(!is.na(parameter)),paste("Chandola",parameter,sep="_"),"Chandola"),
                year=c(year1,year2,year3),
                age=c(age1,age2),
                obs=obs,
                len=len,
                cohort=c((year1-age2),(year1-age1),(year2-age2),(year2-age1))))
  
  ################ Model step
  if(parameter=="arima" | parameter=="freezed"){
    ######## get paramerters
    param <- matrix(NA,nrow=6,ncol=(year3-year1+1))
    colnames(param) <- paste(year1 + c(1:ncol(param))-1)
    param[,colnames(fert.raw)] <- apply(fert.raw,2,Fit_Chandola_fx,par=c(2,0.5,1,26,1,26),method="Nelder-Mead",x=age1:age2)
    
    ######## projections of knots 
    #### arima model
    projection.of.knots.arima <- function(x){
      obj <- auto.arima(as.ts(x[!is.na(x)]),max.p=5,max.d = 2,max.q = 2)
      pre <- forecast(obj,h = length(x)-max(which(!is.na(x))))
      x[c(max(which(!is.na(x)))+1):length(x)] <- pre$mean
      x[x < 0.01] <- 0.01
      return(x)
    }
    #### freezed rate
    projection.of.knots.freezed <- function(x){
      ind <- !is.na(x)
      x[max(which(ind)+1):length(x)] <- x[max(which(ind))]
      return(x)
    }
    
    #### prejection of parameter
    if(parameter[1]=="arima"){
      param[1,] <- projection.of.knots.arima(param[1,])
      param[2,] <- projection.of.knots.arima(param[2,])
      param[3,] <- projection.of.knots.arima(param[3,])
      param[4,] <- projection.of.knots.arima(param[4,])
      param[5,] <- projection.of.knots.arima(param[5,])
      param[6,] <- projection.of.knots.arima(param[6,])
    }
    if(parameter[1]=="freezed"){
      param[1,] <- projection.of.knots.freezed( param[1,])
      param[2,] <- projection.of.knots.freezed( param[2,])
      param[3,] <- projection.of.knots.freezed( param[3,])
      param[4,] <- projection.of.knots.freezed( param[4,])
      param[5,] <- projection.of.knots.freezed( param[5,])
      param[6,] <- projection.of.knots.freezed( param[6,])
    }
    
    ##### project of profile
    for(yr in colnames(raw.data[,is.na(raw.data[1,])])){
      raw.data[,yr] <- Chandola_fx(param[,yr],age1:age2)
    }
    
    ################ Output step
    predASFR=raw.data[,paste(year2+1:len)]
    predCASFR <- asfr_period_to_cohort(raw.data)
    #predCV <- predCASFR[,paste((year2-age1):(year2-age2+1))]
    
    ########
    return(list(pop=pop,
                obsASFR=ASFR,
                obsCASFR=asfr_period_to_cohort(ASFR),
                predASFR=predASFR,
                predCASFR=predCASFR,
                method="Chandola (1999)",
                parameter=parameter,
                label=ifelse(all(!is.na(parameter)),paste("Chandola",parameter,sep="_"),"Chandola"),
                year=c(year1,year2,year3),
                age=c(age1,age2),
                obs=obs,
                len=len,
                cohort=c((year1-age2),(year1-age1),(year2-age2),(year2-age1))))
  }
  
  ######## The original method of Chandola
  if(parameter == "original"){
    # age*period to age*cohort 
    raw.cdata <- asfr_period_to_cohort(fert.raw)
    est.cdata <- raw.cdata
    for(coh in colnames(raw.cdata)){
      data <- raw.cdata[,coh]
      ind <- !is.na(data)
      if(sum(ind)){
        data <- data[ind]
        x <- c(age1:age2)[ind]
        
        #Chandola:
        chandola <-  Fit_Chandola_fx(par=c(2,0.5,1,26,1,26),data=data,x=x,method="Nelder-Mead") 
        chandola.est <- Chandola_fx(chandola,age1:age2)
        est.cdata[,coh] <- chandola.est	
        
      }
    }
    
    ######## original
    ########
    return(list(pop=pop,
                obsASFR=ASFR,
                obsCASFR=asfr_period_to_cohort(ASFR),
                predASFR=asfr_cohort_to_period(est.cdata),
                predCASFR=est.cdata,
                method="Chandola (1999)",
                parameter=parameter,
                label=ifelse(all(!is.na(parameter)),paste("Chandola",parameter,sep="_"),"Chandola"),
                year=c(year1,year2,year3),
                age=c(age1,age2),
                obs=obs,
                len=len,
                cohort=c((year1-age2),(year1-age1),(year2-age2),(year2-age1))))
  }
  
}
