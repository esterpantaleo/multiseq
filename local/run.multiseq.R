#usage
#non interactively
#Rscript run.multiseq.R $samplesheet $chr":"$locus.start"-"$locus.end $multiseq.output.folder "test/multiseq" "chromosome.lengths.hg19.txt" "hg19.ensGene.gp.gz" 
#interactively
#data_name="Encode"
#peak_type="high"
#sim_type="NonNull"
#samplesheet=paste0("~/src/stat45800/tests/simulations/",data_name,"/data/",peak_type,"/chr1.153616385.153747456/",sim_type,"Samplesheet.txt")
#region="chr1:153616385-153747456"
#dir.name="tmp"
library(multiseq)
library(rhdf5)

#********************************************************************
#
#     Get arguments
#
#********************************************************************

args            <- commandArgs(TRUE)
samplesheet     <- args[1]
region          <- args[2]
dir.name        <- file.path(args[3])
fitted.g.file   <- file.path(args[4])
hub.name <- NULL
onlyoneend=TRUE #if bam files are paired end only take one of the reads in the pair
#hub.name        <- args[4]
#chrom.file      <- file.path(args[5])
#assembly        <- args[6]
#annotation.file <- file.path(args[7])


#PARAMETERS  
fra             <- 2      #how many sd to plot when plotting effect size    
do.plot         <- FALSE
do.smooth       <- FALSE
do.summary      <- TRUE
do.save         <- TRUE #FALSE #TRUE
prior           <- "nullbiased" 
lm.approx       <- FALSE #=TRUE #so far we run things with approx=FALSE
                             
samples         <- read.table(samplesheet, stringsAsFactors=F, header=T)   
g               <- factor(samples$Tissue)
g               <- match(g, levels(g)) - 1  

split_region <- unlist(strsplit(region, "\\:|\\-"))
chr          <- split_region[1]
locus.start  <- as.numeric(split_region[2])
locus.end    <- as.numeric(split_region[3])
locus.name   <- paste(chr, locus.start, locus.end, sep=".")
dir.create(dir.name)
dir.name     <- file.path(dir.name, locus.name)
dir.create(dir.name)
                             
M <- get.counts(samples, region, onlyoneend=TRUE)

if (sum(M)<10){
    if (do.summary){
        write.table(t(c(chr, locus.start, locus.end, NA, NA)),
                    quote = FALSE,
                    col.names=FALSE,
                    row.names=FALSE,
                    file=file.path(dir.name,"summary.txt"))
    }
    stop("Total number of reads over all samples is <10. Stopping.")
}
set.fitted.g=NULL
set.fitted.g.intercept=NULL
if (fitted.g.file!="NA"){
    load(fitted.g.file)
    set.fitted.g=ret$fitted.g
    set.fitted.g.intercept=ret$fitted.g.intercept
}
if (do.summary)
    ptm      <- proc.time()

res <- multiseq(M, g=g, minobs=1, lm.approx=lm.approx, read.depth=samples$ReadDepth, prior=prior, set.fitted.g=set.fitted.g, set.fitted.g.intercept=set.fitted.g.intercept)
warnings() #print warnings

if (do.summary){
    my.time  <- proc.time() - ptm
}

res$chr=chr
res$locus.start=locus.start
res$locus.end=locus.end
res <- get.effect.intervals(res,fra)

if (do.save){
    #save results in a compressed file
    write.effect.mean.variance.gz(res,dir.name)
    write.effect.intervals(res,dir.name,fra=2)
    write.table(t(c(res$logLR$value, res$logLR$scales)), quote=FALSE, col.names=FALSE, row.names=FALSE, file=file.path(dir.name,paste0("logLR_",prior,".txt")))
}

if (do.summary){
    Neffect2=get.effect.length(res,fra=2)
    Neffect3=get.effect.length(res,fra=3) 
    write.table(t(c(chr, locus.start, locus.end, Neffect2, Neffect3, my.time[1])),
                quote=FALSE, col.names=FALSE, row.names=FALSE, file=file.path(dir.name,"summary.txt"))
}

#plotting
if (do.plot){
    print("Plot Effect")
    # Extract gene model from genePred annotation file
    Transcripts <- get.Transcripts(annotation, chr, locus.start, locus.end)

    pdf(file=file.path(dir.name, "Effect.pdf"))
    layout(matrix(c(1,2), 2, 1, byrow = FALSE))
    #centipede <- read.table("/mnt/lustre/data/share/DNaseQTLs/CentipedeAndPwmVar/CentipedeOverlapMaxP99.UCSC
    #sites     <- centipede[centipede[,1] == chr & centipede[,2] < (locus.end+1) & centipede[,3] > locus.start, ]
    #offset    <- -0.25 #0.0025 
    #if (dim(sites)[1] > 0){for (k in 1:dim(sites)[1]){offset <-  -offset
    #text(x=(sites[k,2] + sites[k,3])/2, y=(ymax/2 -abs(offset) - offset), strsplit(as.character(sites[k,4]), split="=")[[1]][2])
    #rect(sites[k,2], 0, sites[k,3], ymax/2 + 1, col=rgb(0,0,1,0.3), border='NA')}}
    par(mar=c(0,3,2,1))
    plotResults(res)
    par(mar=c(4,3,0,1))
    plotTranscripts(Transcripts, locus.start, locus.end)
    dev.off()
}

#************************************************************
#
#    Apply cyclespin to each genotype class
#
#*************************************************************
if (do.smooth==TRUE){
    print("Smooth by group")
    res0 <- multiseq(M[g==0,], minobs=1, lm.approx=lm.approx, read.depth=samples$ReadDepth[g==0])
    res1 <- multiseq(M[g==1,], minobs=1, lm.approx=lm.approx, read.depth=samples$ReadDepth[g==1])
    
    if (do.plot==TRUE){
        print("Plot smoothed signals")
        pdf(file=file.path(dir.name,"Smoothing_by_group.pdf"))
        ymax <- max(c(as.vector(res0$est + fra*sqrt(res0$var)), as.vector(res1$est + fra*sqrt(res1$var))))
        ymin <- min(c(as.vector(res0$est - fra*sqrt(res0$var)), as.vector(res1$est - fra*sqrt(res1$var))))
        ylim <- c(ymin, ymax)
        layout(matrix(c(1,2,3,4), 4, 1, byrow = FALSE))
        par(mar=c(0,3,2,1))
        plotResults(res0, title=paste0("Smoothed ", samples$Tissue[g==0][1]), ylim=ylim, type="baseline")
        par(mar=c(0,3,2,1))
        plotResults(res1, title=paste0(samples$Tissue[g==1][1]), ylim=ylim, type="baseline")
        par(mar=c(0,3,2,1))
        plotTranscripts(Transcripts, locus.start, locus.end)
        dev.off()
    }
}

if (!is.null(hub.name)){
    multiseq.folder=file.path(args[3]) 
    multiseqToTrackHub(region, hub.name, multiseq.folder, chrom.file, assembly)
}
