


#' working on this function still
#' The goal is to use a basic elastic net regression to identify how 
#' well each molecular feature predicts outcome as well as how many features
#' are selected
#' @import glmnet
#' @param clin.data is tidied clinical data
#' @param mol.data is tidied table of molecular data
#' @param mol.feature is name of column to select from mol.data
#' @param category can be either Condition or family
#' @export 
drugMolRegression<-function(clin.data,
                            mol.data,
                            mol.feature,
                            category='Condition'){
  
   
  if(length(mol.feature)==1){
    drug.mol<-clin.data%>%
      dplyr::select(`AML sample`,var=category,percAUC)%>%
       group_by(`AML sample`,var)%>%
      summarize(meanVal=mean(percAUC,na.rm=T))%>%
      left_join(select(mol.data,c(Gene,`AML sample`,!!mol.feature)),
                by='AML sample')
  
  
    reg.res<-drug.mol%>%group_by(var)%>%
      group_modify(~ miniReg(.x,mol.feature),keep=T)%>%
      mutate(Molecular=mol.feature)
  }else{
    drug.mol<-clin.data%>%
      dplyr::select(`AML sample`,var=category,percAUC)%>%
      group_by(`AML sample`,var)%>%
      summarize(meanVal=mean(percAUC,na.rm=T))%>%
      left_join(select(mol.data,c(Gene,`AML sample`,mol.feature)),
                by='AML sample')
    reg.res<-drug.mol%>%group_by(var)%>%
      group_modify(~ combReg(.x,mol.feature),keep=T)%>%
      mutate(Molecular=paste(mol.feature,collapse='_'))
  }
  return(reg.res)
  
}

#' combReg
#' Runs lasso regression on a combination of feature types
#' @param tab
#' @param feature.list
#' @return a data frame with three values/columns
combReg<-function(tab,feature.list=c('proteinLevels','mRNALevels','geneMutations')){
  
   comb.mat<-do.call('cbind',lapply(feature.list,function(x) buildFeatureMatrix(tab,x)))
   
   
  # cm<-apply(comb.mat,1,mean)
  # zvals<-which(cm==0)
  # if(length(zvals)>0)
  #   comb.mat<-comb.mat[-zvals,]
   
   
  if(ncol(comb.mat)<5 || nrow(comb.mat)<5)
    return(data.frame(MSE=0,numGenes=0,genes=''))
  
  #now collect our y output variable
  tmp<-tab%>%
    dplyr::select(meanVal,`AML sample`)%>%
    distinct()
  yvar<-tmp$meanVal
  names(yvar)<-tmp$`AML sample`
  yvar<-unlist(yvar[rownames(comb.mat)])
  
  #use CV to get maximum AUC
  cv.res=cv.glmnet(x=comb.mat,y=yvar,type.measure='mse')
  best.res<-data.frame(lambda=cv.res$lambda,MSE=cv.res$cvm)%>%
    subset(MSE==min(MSE))
  
  #then select how many elements
  full.res<-glmnet(x=comb.mat,y=yvar,type.measure='mse')
  genes=names(which(full.res$beta[,which(full.res$lambda==best.res$lambda)]!=0))
  genelist<-paste(genes,collapse=',')
  #print(paste(best.res$MSE,":",genelist))
  return(data.frame(MSE=best.res$MSE,numGenes=length(genes),genes=genelist))
  
  
}

#' buildFeatureMatrix
#' Builds a matrix for regression with rows as patients and columns as gene
#' @param tab
#' @param mol.feature
#' @return matrix
buildFeatureMatrix<-function(tab,mol.feature){
  print(mol.feature)
  vfn=list(0.0)
  names(vfn)=mol.feature
  vfc<-list(mean)
  names(vfc)=mol.feature

  mat<-tab%>%
  dplyr::select(`AML sample`,Gene,!!mol.feature)%>%
    subset(Gene!="")%>%
    tidyr::pivot_wider(names_from=Gene,values_from=mol.feature,
                     values_fill=vfn,values_fn = vfc,names_prefix=mol.feature)%>%
    tibble::column_to_rownames('AML sample')

  mat<-apply(mat,2,unlist)
  return(mat)
}
#' miniReg
#' Runs lasso regression on a single feature from tabular data
#' @param tab with column names `AML sample`,meanVal,Gene, and whatever the value of 'mol.feature' is.
#' @return a data.frame with three values/columns: MSE, NumGenes, and Genes
miniReg<-function(tab,mol.feature){
  library(glmnet)
  
  #first build our feature matrix
 mat<-buildFeatureMatrix(tab,mol.feature)

 cm<-apply(mat,1,mean)
 zvals<-which(cm==0)
 if(length(zvals)>0)
   mat<-mat[-zvals,]
 
  if(ncol(mat)<5 || nrow(mat)<5)
      return(data.frame(MSE=0,numGenes=0,genes=''))

  #now collect our y output variable
  tmp<-tab%>%
     dplyr::select(meanVal,`AML sample`)%>%
      distinct()
  yvar<-tmp$meanVal
  names(yvar)<-tmp$`AML sample`
  yvar<-unlist(yvar[rownames(mat)])
  
  #use CV to get maximum AUC
  cv.res=cv.glmnet(x=mat,y=yvar,type.measure='mse')
  best.res<-data.frame(lambda=cv.res$lambda,MSE=cv.res$cvm)%>%
    subset(MSE==min(MSE))
  
  #then select how many elements
  full.res<-glmnet(x=mat,y=yvar,type.measure='mse')
  genes=names(which(full.res$beta[,which(full.res$lambda==best.res$lambda)]!=0))
  genelist<-paste(genes,collapse=',')
  #print(paste(best.res$MSE,":",genelist))
  return(data.frame(MSE=best.res$MSE,numGenes=length(genes),genes=genelist))
}


#' how do we visualize the correlations of each drug/gene pair?
#' 
#' Computes drug by element correlation and plots them in various ways
#' @param cor.res
#' @param cor.thresh 
#' @import ggplot2
#' @import dplyr
#' @import cowplot
#' @import ggridges
#' @export
plotCorrelationsByDrug<-function(cor.res,cor.thresh){
  ##for each drug class - what is the distribution of correlations broken down by data type
  library(ggplot2)
  library(dplyr)
  do.p<-function(dat,cor.thresh){
    print(head(dat))
    fam=dat$family[1]
    #fam=dat%>%dplyr::select(family)%>%unlist()
    #fam=fam[1]
    fname=paste0(fam,'_correlations.png')
    p1<-ggplot(dat,aes(y=Condition,x=drugCor))+
      geom_density_ridges_gradient(aes(fill=feature,alpha=0.5))+
      scale_fill_viridis_d()+ggtitle(paste('Correlation with',fam))
    ##for each drug, how many genes have a corelation over threshold
    p2<-subset(dat,abs(drugCor)>cor.thresh)%>%
      ungroup()%>%
      group_by(Condition,feature,family)%>%
      summarize(CorVals=n_distinct(Gene))%>%ggplot(aes(x=Condition,y=CorVals,fill=feature))+
      geom_bar(stat='identity',position='dodge')+
      scale_fill_viridis_d()+ggtitle(paste("Correlation >",cor.thresh))+ 
      theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
    
    cowplot::plot_grid(p1,p2,nrow=2) 
    
    ggsave(fname)
    return(fname)
  }
  
  famplots<-cor.res%>%split(cor.res$family)%>%purrr::map(do.p,cor.thresh)                                                  
  
  lapply(famplots,synapseStore,'syn22130776')
  
}


#'Nots ure if this is used yet
#'Currently deprecated
computeDiffExByDrug<-function(sens.data){
  #samps<-assignSensResSamps(sens.data,'AUC',sens.val,res.val)
  
  result<-sens.data%>%
    dplyr::select('Sample',Gene,cellLine='Drug',value="LogFoldChange",treatment='Status')%>%
    distinct()%>%
    subset(!is.na(cellLine))%>%
    group_by(cellLine)%>%
    group_modify(~ computeFoldChangePvals(.x,control=NA,conditions =c("Sensitive","Resistant")),keep=TRUE)%>%
    rename(Drug='cellLine')
  
  
  table(result%>%group_by(Drug)%>%subset(p_adj<0.1)%>%summarize(sigProts=n()))
  
  result
}


#' what molecules are
#' @import dplyr
#' @param clin.data
#' @param mol.data
#' @param mol.feature
#' @export  
computeAUCCorVals<-function(clin.data,mol.data,mol.feature){
  tdat<-mol.data%>%
    dplyr::select(Gene,`AML sample`,Mol=mol.feature)%>%
    subset(!is.na(Mol))%>%
    inner_join(clin.data,by='AML sample')
  
  print('here')
  dcors<-tdat%>%select(Gene,Mol,Condition,AUC)%>%
    distinct()%>%
    group_by(Gene,Condition)%>%
    mutate(numSamps=n(),drugCor=cor(Mol,AUC))%>%
    dplyr::select(Gene,Condition,numSamps,drugCor)%>%distinct()%>%
    arrange(desc(drugCor))%>%
    subset(numSamps>10)%>%
    mutate(feature=mol.feature)
  
  return(dcors)
  
}