#' @title Check if executable is in user's PATH.
#' @param name: the name of the executable.
#' @export
noExecutable <- function(name){
    if(Sys.which(name)==""){
        warning(paste("cannot find function",name))
        return(1)
    }
    return(0)
}

#' @title Write \code{genomes.txt} and \code{hub.txt} files
#' @keywords internal
#' @export
writeTrackHubSkeleton <- function(hub_dir, assembly="hg19", hub_name_string, email="fake_email_address@dot.com"){
    assembly_dir = file.path(hub_dir, assembly)
    
    #write genomes file
    print("write genomes file")
    cat(paste0("genome ", assembly, "\n",
               'trackDb ', assembly, "/trackDbFile.txt\n"),
        file=file.path(hub_dir, 'genomes.txt'), append=FALSE)
    
    #write hub file
    print("write hub file")
    cat(paste0('hub ', hub_name_string, "\n",
               'shortLabel ', hub_name_string, "\n",
               'longLabel ', hub_name_string, "\n",
               "genomesFile genomes.txt\n",
               'email ', email, "\n"),
        file=file.path(hub_dir, 'hub.txt'), append=FALSE)
}


#' @title Write a superTrack.
#' @keywords internal
appendBedSuperTrack <- function(track, shortLabel, longLabel, tracks, shortLabels, longLabels, color, priority=2, out_file){
    cat(paste0('track ', track, "\n",
               'shortLabel ', shortLabel, "\n",
               'longLabel ', longLabel, "\n",
               "superTrack on none\n",
               'priority ', priority, "\n",
               "dragAndDrop subtracks\n\n"), file=out_file, append=TRUE)
    
    for (i in 1:length(tracks))
        cat(paste0('track signal', shortLabels[i], "\n",
                   "type bigBed\n",
                   'shortLabel ', shortLabels[i], "\n",
                   'longLabel ', longLabels[i], "\n",
                   'parent ', track, "\n",
                   "visibility full\n",
                   'bigDataUrl ', tracks[i], "\n",
                   'color ', color, "\n"), file=out_file, append=TRUE)
}

#' @title Write a track with.
#' @keywords internal 
appendBigWigTrack <- function(sampleid, bigwig_track, hub_name_string,assembly_dir){
    cat(paste0("track ", sampleid, "\n",
               "parent reads\n",
               "type bigWig\n",
               "graphType points\n",
               "visibility full\n",
               "color 0,0,0\n",
               "bigDataUrl ", bigwig_track, "\n",
               "track ", sampleid, "\n",
               "parent reads\n",
               "type bigWig\n",
               "graphType points\n",
               "visibility full\n",
               "color 0,0,0\n",
               "bigDataUrl ", bigwig_track, "\n",
               "shortLabel ", sampleid, "\n",
               "longLabel ", hub_name_string, " ", sampleid, "\n\n"),
        file=file.path(assembly_dir, "trackDbFile.txt"),
        append=TRUE)
}


#' @title Write a message containing instructions on how to visualize the Track Hub.
#' @keywords internal
printGoToMessage <- function(hub_name, assembly, hub_dir, http_address, region=NULL){
    #print the link to the UCSC Genome Browser page with the track already loaded
    toprint=paste0("go to http://genome.ucsc.edu/cgi-bin/hgTracks?db=", assembly, "&hubUrl=", http_address, "/", hub_name, "/hub.txt\n")
    if (!is.null(region)){
        toprint=paste0(toprint,"center the genome browser around ", region, "\n")
    }else{
        toprint=paste0(toprint,"center the genome browser on the region of interest\n")
    }
    toprint=paste0(toprint, "and make track visible\n")
    toprint=paste0(toprint,"(track has been saved in folder ", hub_dir, ")\n")
    
    cat(toprint)
}

#' @title Convert \code{hdf5} file to \code{bigWig} only extracting counts from a specified chromosome.   
#'
#' @description This function requires the executable \code{wigToBigWig} to be in the user's PATH. It converts \code{h5_track} into \code{bigWig_track.bw} using data in chromosome \code{chr} and \code{chromosome_file} containing chromosome names and lengths.  
#' 
#' @param h5_track: path to the \code{hdf5} track.
#' @param chrom_file: path to the file containing chromosome names and lengths.
#' @param chr: extract counts from this chromosome.
#' @param bigWig_track: name of new \code{bigWig} track.
#' @param assembly: genome assembly that reads were mapped to; default="hg19".
#' @return no return; it prints to a file.
#' @keywords internal
#' @examples
#' \dontrun{ 
#' hdf5ToBigWig("in.h5", "chromosome_file", "chr1", "out")
#' }
hdf5ToBigWig <- function(h5_track, chrom_file, chr=NULL, bigWig_track, assembly="hg19"){
    if (noExecutable("wigToBigWig"))
        return(1)
    chromosomes = read.table(chrom_file, stringsAsFactors=FALSE)
    if (is.null(h5_track) | is.null(chr) | is.null(chrom_file) | is.null(bigWig_track))
        stop("specify required arguments: h5_track, chrom_file, chromosome name, bigWig_track")
    counter=0
    for (i in 1:nrow(chromosomes)){
        if (chromosomes[i,1]==chr){
            counter=1
            print(paste("processing chromosome ", chromosomes[i,1]))
            zz <- pipe(paste("wigToBigWig stdin", bigWig_track), "w")
            cat("fixedStep chrom=%s start=1 step=1", h5read(h5_track, chromosomes[i,1], index=list(1:chromosomes[i,2])), sep="\n", file=zz)
            close(zz)
            break
        }
    }
    if (counter==0){
        stop(paste("chr", chr, "not found in file", chrom_file))
    }
    return(0)
}

#' @title Convert \code{bam} file to \code{bigWig} only extracting counts from a specified chromosome. By default both ends of a paired end read are counted as independent reads.
#'
#' @description This function requires the executables \code{wigToBigWig} and \code{samtools} to be in the user's PATH. It converts \code{bam_track} into \code{bigWig_track.bw} using data from \code{chr} and \code{chromosome_file}, a tabulated file containing chromosome names and lengths. 
#' 
#' @param bam_track: path to the \code{bam} track.
#' @param chrom_file: path to the tabulated file containing chromosome names and lengths
#' @param chr: extract counts from the specified chromosome
#' @param bigWig_track: name of new \code{bigWig} track
#' @param onlyoneend: a bool, defaults to FALSE; use TRUE if input is in bam format and only first end of the paired end read should be used. 
#' @return no return; it prints to a file
#' @keywords internal
#' @examples
#' \dontrun{ 
#' bamToBigWig("in.bam", "chromosome_file", "chr1", "out", onlyoneend=TRUE)
#' }
bamToBigWig <- function(bam_track, chrom_file, chr, track_name, onlyoneend){
    if (noExecutable("samtools"))
        return(1)
    if (noExecutable("wigToBigWig"))
        return(1)
    if (noExecutable("awk"))
        return(1)
    chromosomes = read.table(chrom_file, stringsAsFactors=FALSE)
    counter=0
    for (i in 1:nrow(chromosomes)){
        if (chromosomes[i,1]==chr){
            counter=1
            break
        }
    }
    if (counter==0)
        stop(paste("chr", chr, "not found in file", chrom_file))
    
    for (i in 1:nrow(chromosomes)){
        if (chromosomes[i,1]==chr){
            if (onlyoneend==TRUE){
                cmd <- paste("samtools view -f 64", track_name)
            }else{
                cmd <- paste("samtools view", track_name)
            }
            cmd <- paste0(cmd,
                          "| awk -v C=\"chr\" 'BEGIN{start=1; count=0; print \"fixedStep chrom=\"C\" start=1 step=1\n\"}",
                          "{st=$4; if (st>start) {toprint=count; if (st-start>1) for (i=1; i<st-start; i++) print 0; start=st; count+=1;}", 
                          "else if (st==start) count+=1;}'| ",
                          "wigToBigWig stdin",
                          chrom_file,
                          track_name)
            print(paste("running", cmd, "..."))
            dir.create(dirname(track_name), showWarnings=FALSE, recursive=TRUE)
            system(cmd)
            break
        }
    }
    return(0)
}

#' @title Create a UCSC Genome Browser "Track Hub" from read tracks and bed tracks (of significant intervals) listed in a \code{samplesheet}.
#'
#' @description This function requires the executables \code{wigToBigWig}, \code{bedToBigBed}, and \code{bigWigInfo} to be in the user's PATH.
#' Read tracks can be in \code{bam}, \code{hdf5}, \code{bigWig}, \code{bed} or \code{bigBed} format and significant intervals can only be in bed format. If in \code{bam} format by default both ends of a paired end read are counted as independent reads (control this behavior with parameter onlyoneend).
#'
#'
#' @param samplesheet: a string specifying the path to the samplesheet;
#' for specifications of the samplesheet format see the vignette.
#' A column with header \code{sampleID} is required; either a column
#' with header \code{h5FullPath}, or a column with header \code{bigWigPath},
#' or a column with header \code{bamReads} containing the path to the \code{hdf5}
#' files or the \code{bigWig} files or the \code{bam} files, respectively,
#' should be specified. If the samplesheet has a column with header \code{Peaks}
#' (specifying the path to a \code{bed} or \code{bigBed} file) it must also
#' have a column with header \code{Type}. Depending on the size of the files this code might require a lot of memory.
#' @param hub_name: name of the Track Hub; this string can be set to any value; it could contain a path, in which case the path will be relative to the mountpoint (see below); defaults ito \code{paste0(basename(samplesheet),".TrackHub")}.
#' @param chrom_file: path to the file containing chromosome names and lengths; defaults \code{system.file("extdata", "chromosome.lengths.hg19.txt", package="multiseq")}.
#' @param chr: a string, restrict ouput to the selected chromosome \code{chr}.
#' @param assembly: genome assembly that reads were mapped to; defaults to "hg19". 
#' @param mountpoint: path to the directory where the track hub folder will be saved in; this directory should be associated with an \code{http address} or an \code{ftp address}; defaults to \code{Sys.getenv("MOUNTPOINT_PATH")}.
#' @param http_address: http or ftp address associated with the mountpoint; defaults to \code{Sys.getenv("MOUNTPOINT_PATH")}.
#' @param onlyoneend: a bool, defaults to FALSE; use TRUE if input is in \code{bam} format and only first end of the paired end read should be used.
#' @export
#' @examples
#'\dontrun{
#' setwd(file.path(path.package("multiseq"),"extdata","sim"))
#' samplesheet="samplesheet.sim.txt"
#' samplesheetToTrackHub(samplesheet, chr="chr1")
#' }  
samplesheetToTrackHub <- function(samplesheet, hub_name=paste0(basename(samplesheet),".TrackHub"), chrom_file=system.file("extdata", "chromosome.lengths.hg19.txt", package="multiseq"), chr=NULL, assembly="hg19", mountpoint=Sys.getenv("MOUNTPOINT_PATH"), http_address=Sys.getenv("MOUNTPOINT_HTTP_ADDRESS"), onlyoneend=FALSE){
    error=0
    if (noExecutable("bigWigInfo"))
        return()
    if (noExecutable("grep"))
        return()
    if (noExecutable("tr"))
        return()
    if (is.null(samplesheet) | is.null(chr))
        stop("specify chromosome and/or samplesheet")
    if (mountpoint=="" | http_address==""){
        warnings("the mountpoint and/or the mountpoint email address are not defined; in order to use this function follow package installation instructions")
        return()
    }
    
    if (is.null(hub_name)) hub_name=paste0(basename(samplesheet),".TrackHub")
    samples         <- read.table(samplesheet, stringsAsFactors=F, header=T)
    hub_dir         <- file.path(mountpoint, hub_name)
    hub_name_string <- gsub("/", ".", hub_name)
    dir.create(hub_dir, showWarnings = FALSE, recursive=TRUE)
    assembly_dir    <- file.path(hub_dir, assembly)
    dir.create(assembly_dir, showWarnings = FALSE, recursive=TRUE) 
    sampleids       <-  samples$SampleID
    
    bigwig_tracks <- NULL
    if ("bigWigPath" %in% colnames(samples)){
        for (bigwig_track in samples$bigWigPath){
            track_name    <- basename(bigwig_track)
            dir.create(file.path(assembly_dir, dirname(track_name)), showWarnings = FALSE, recursive=TRUE)
            file.copy(from=bigwig_track, to=assembly_dir, overwrite=TRUE) 
            print(paste0("file.copy(from=", bigwig_track, "to=", file.path(assembly_dir, track_name)))
            bigwig_tracks <- c(bigwig_tracks, track_name)
        }
    }else if ("h5FullPath" %in% colnames(samples)){
        for (h5_track in samples$h5FullPath){
            track_name    <- basename(h5_track)
            error         <- hdf5ToBigWig(h5_track, chrom_file, chr, track_name, assembly)
            bigwig_tracks <- c(bigwig_tracks, track_name)
        }
    }else if ("bamReads" %in% colnames(samples)){
        for (bam_track in samples$bamReads){
            track_name    <- basename(bam_track)
            error         <- bamToBigWig(bam_track, chrom_file, chr, track_name, onlyoneend=onlyoneend)
            bigwig_tracks <- c(bigwig_tracks, track_name)
        }
    }else{
        stop("no input file provided: provide paths to input files (in hdf5, bigWig or bam format) in the samplesheet file.")
    }
    if (error)
        return()
    #if no error
    writeTrackHubSkeleton(hub_dir, assembly, hub_name_string)
    cat(paste0("track reads\n",
               "shortLabel reads\n",
               "longLabel reads\n",
               "superTrack on none\n",
               "priority 1\n"), 
        file=file.path(assembly_dir, "trackDbFile.txt"),
        append=FALSE)
    
    #if bigWig files cover a region smaller than 2^20
    #use viewLimits
    command      <- paste0("bigWigInfo ", file.path(assembly_dir, bigwig_tracks[1]), " | grep basesCovered | tr -d \",\"" )
    bigWigLength <- unlist(strsplit(system(command, intern=TRUE)[1], " "))[2]
    if (bigWigLength<2^20){
        #find ymax over all bigwig files
        bigWigM=0
        for (bigwig_track in bigwig_tracks){
            command   <- paste("bigWigInfo -minMax", file.path(assembly_dir, bigwig_track))
            bigWigMax <- unlist(strsplit(system(command, intern=TRUE)[1], " "))[2] 
            bigWigM   <- max(bigWigM, bigWigMax)
        }
        message=paste0("autoScale off\n","viewLimits 0:",bigWigM)
    }else{
        message="autoScale on"
    }
    cat(paste0(message,"\ndragAndDrop subtracks\n\n"), file=file.path(assembly_dir, "trackDbFile.txt"),append=TRUE)

    #write bigWig tracks
    counter=1
    for (bigwig_track in bigwig_tracks){
        appendBigWigTrack(sampleids[counter], bigwig_track, hub_name_string, assembly_dir)
        counter=counter+1
    }
    #if bed files are available in the samplesheet
    #convert bed files into bigBed
    if ("Peaks" %in% colnames(samples)){
        error=0
        peaks_files  <- unique(samples$Peaks)
        peaks_files  <- peaks_files[which(peaks_files!="-")]
        if (length(peaks_files)!=0){
            tissues       <- unique(samples$Type)
            bigbed_tracks <- NULL
            for (peaks_track in peaks_files){
                track_name <- basename(peaks_track)
                #if peack are in bigBed format already
                if (file_ext(track_name)=="bb"){
                    dir.create(file.path(assembly_dir, dirname(track_name)), showWarnings = FALSE, recursive=TRUE)
                    file.copy(from=peaks_track, to=file.path(assembly_dir, track_name))
                    bigbed_tracks <- c(bigbed_tracks, track_name)
                }else{#if peaks are in bed format
                    if (noExecutable("bedToBigBed")){
                        error=1
                    }else{
                        #convert bed file into bigBed file
                        bigbed_track <- paste0(track_name, '.bb')
                        cmd          <- paste("bedToBigBed -type=bed6+4",
                                              peaks_track,
                                              chrom_file,
                                              file.path(hub_dir, bigbed_track))
                        print(cmd)
                        system(cmd)
                        bigbed_tracks <- c(bigbed_tracks, bigbed_track)
                    }
                }
            }
            #write the track hub
            if (error==0){
                appendBedSuperTrack("peaks", "peaks", "peaks", bigbed_tracks, tissues, paste0(hub_name_string,tissues), "0,0,0", out_file=file.path(assembly_dir, "trackDbFile.txt"))
            }
        }
    }
    printGoToMessage(hub_name, assembly, hub_dir, http_address)
}

    

#' @title Write a vector of counts to a \code{bigWig} file given position and sequence information
#'
#' @param x: an R vector of (per base) counts
#' @param chr: sequence name
#' @param start: position on the sequence "chr" where the counting process started
#' @param chrom_file: path to the file containing chromosome names and lengths
#' @param bigWigFile: path to the output \code{bigWig} file, defaults to "out.wg"
#' @export
#' @keywords internal
vectorToBigWig <- function(x, chr, start, chrom_file, bigWigFile="out.wg"){
    cmd = paste("wigToBigWig stdin", chrom_file, bigWigFile)
    print(paste("running", cmd, "..."))
    dir.create(dirname(bigWigFile), showWarnings=FALSE, recursive=TRUE)
                                        #pipe results to the wigToBigWig executable
    zz <- pipe(cmd, "w")
    cat(paste0("fixedStep chrom=",
               chr,
               " start=",
               start,
               " step=1"),
        x,
        sep="\n",
        file=zz)
    close(zz)
}



#' @title Write a \code{bigBed} file given the output of \code{get.ffect.intervals}
#'
#' @param intervals: output of get.effect.intervals
#' @param chrom_file: path to the file containing chromosome names and lengths
#' @param bigBedFile: output file, defaults to "out.bb"
#' @export
#' @keywords internal
intervalsToBigBed <- function(intervals, chrom_file, bigBedFile="out.bb"){
    tmp_bed_file=paste0(dirname(bigBedFile),".bed")
    write.bed(intervals, tmp_bed_file)
    if (noExecutable("bedToBigBed"))
        return(1)
    cmd=paste("bedToBigBed", tmp_bed_file, chrom_file, bigBedFile)
    print(paste("running", cmd, "..."))
    system(cmd)
    file.remove(tmp_bed_file)
    return(0)
}

writeTrackdbFile <- function(fra, assembly_dir){
        cat("track SuperTrack\n",
            "shortLabel multiseq\n",
            paste("longLabel Plot of multiseq effect", fra, "sd\n"),
            "superTrack on none\n",
            "priority 1\n\n",
            "track CompositeTrack\n",
            "container multiWig\n",
            "configurable on\n",
            "shortLabel Effect\n",
            "longLabel multiseq\n",
            "visibility full\n",
            "type bigWig\n",
            "autoScale on\n",
            "aggregate transparentOverlay\n",
            "windowingFunction mean\n",
            "superTrack SuperTrack full\n",
            "showSubtrackColorOnUi on\n",
            "smoothingWindow off\n",
            "dragAndDrop subtracks\n\n",
            file=file.path(assembly_dir, 'trackDbFile.txt'))
    }
#' @title Create a UCSC genome browser "Track Hub" from \code{\link{multiseq}} output.
#'
#' @description This function requires the executables \code{wigToBigWig} and
#' \code{bedToBigBed} to be in the user's PATH. By default this function uses
#' the human genome \code{hg19}. To use this function with a different genome
#' specify \code{chrom_file} and \code{assembly}.
#'
#' @param res: output of \code{\link{multiseq}}; \code{res$region} should be
#' defined (e.g.: \code{res$region="chr1:2345-234567")}; a valid region must
#' contain sequence_name:locus_start-locus_end
#' @param fra: a multiplier of the standard deviation; this function will create
#' a Truck Hub with the effect at plus or minus \code{fra} * posterior standard
#' deviation; by default the function will use \code{fra=res$fra}

#' @param hub_name: name of the Track Hub; this string can be set to any value;
#' it could contain a path, in which case the path will be relative to the
#' mountpoint; default="multiseq"
#' @param chrom_file: path to the file containing chromosome names and lengths;
#' default is \code{system.file("extdata", "chromosome.lengths.hg19.txt", package="multiseq")}
#' @param assembly: genome assembly that reads were mapped to; default="hg19"
#' @param mountpoint: path to the directory where the Track Hub folder will be
#' saved in. This directory should be associated with an http address or an
#' ftp address; default=\code{Sys.getenv("MOUNTPOINT_PATH")}
#' @param http_address: http or ftp address associated with the mountpoint;
#' default=\code{Sys.getenv("MOUNTPOINT_PATH")}
#' @export
#' @examples
#' \dontrun{
#' region="chr1:154206209-154214400"
#' #res is the putput of multiseq
#' res$region <- region
#' multiseqToTrackHub(res)
#' } 
multiseqToTrackHub <- function(res, fra=NULL, hub_name="multiseq", chrom_file=system.file("extdata", "chromosome.lengths.hg19.txt", package="multiseq"), assembly="hg19", mountpoint=Sys.getenv("MOUNTPOINT_PATH"), http_address=Sys.getenv("MOUNTPOINT_HTTP_ADDRESS")){
                                        #check executables and input
    if (mountpoint=="" | http_address==""){
        warnings("the mountpoint and/or the mountpoint email address are not defined; in order to use this function follow package installation instructions")
        return()
    }
    if (noExecutable("wigToBigWig"))
        return()
    if (is.null(fra)&is.null(res$fra))
        stop("Define res$fra fra, see help")
    if (is.null(fra))
        fra=res$fra
    if (is.null(res$region))
        stop("Define res$region, see help")
    if (is.null(res$effect.mean) | is.null(res$effect.var))
        stop("No effect or effect var in multiseq output")
    split_region = unlist(strsplit(res$region, "\\:|\\-"))
    if (length(split_region) != 3)
        stop("Invalid region")
    chrom = split_region[1]
    locus_start = as.numeric(split_region[2])
    locus_end = as.numeric(split_region[3])
    if (locus_start%%1 | locus_end%%1 | locus_end-locus_start<1) #check that locus.start
        stop("Invalid region")

    #create directories
    hub_dir = file.path(mountpoint, hub_name)
    hub_name_string = gsub("/", ".", hub_name)
    dir.create(hub_dir, showWarnings = FALSE, recursive=TRUE)
    assembly_dir = file.path(hub_dir, assembly)
    dir.create(assembly_dir, showWarnings = FALSE, recursive=TRUE)
    
    #create bigWig file with mean
    mean_track = file.path(assembly_dir, "mean_track.bw")
    vectorToBigWig(res$effect.mean,
                   chrom,
                   locus_start,
                   chrom_file,
                   mean_track) 
    #create bigWig file with mean+fra*sd
    mean_plus_track = file.path(assembly_dir, "mean_plus_track.bw")
    vectorToBigWig(res$effect.mean+fra*sqrt(res$effect.var),
                   chrom,
                   locus_start,
                   chrom_file,
                   mean_plus_track)
    #create bigWig file with mean-fra*sd
    mean_minus_track = file.path(assembly_dir, "mean_minus_track.bw")
    vectorToBigWig(res$effect.mean-fra*sqrt(res$effect.var),
                   chrom,
                   locus_start,
                   chrom_file,
                   mean_minus_track)
    
    #create bigBed file with regions with strong signal
    intervals <- get.effect.intervals(res, fra=fra, res$region)
    no_bed=TRUE
    if (!is.null(intervals$start)){
        if (noExecutable("bedToBigBed")){
            no_bed=TRUE
        }else{
            no_bed=FALSE
            multiseq_peaks_track = file.path(assembly_dir, "multiseq_bed_file.bb")
            intervalsToBigBed(intervals, chrom_file, multiseq_peaks_track)
        }
    }   

    #make track hub
    print("write Track Hub Skeleton")
    writeTrackHubSkeleton(hub_dir, assembly, hub_name_string)
    #write trackdb_file
    print("write trackdb_file")
    writeTrackdbFile(fra, assembly_dir)
    shortLabel=c("Mean",
        paste0("MeanPlus",fra,"Sd"),
        paste0("MeanMinus",fra,"Sd"))
    longLabel=c("multiseq mean effect",
        paste("multiseq effect mean -", fra, "* sd"),
        paste("multiseq effect mean +", fra, "* sd"))
    bigDataUrl=c("mean_track.bw", "mean_plus_track.bw", "mean_minus_track.bw")
    color=c("0,0,0", "0,255,0", "0,255,0")
    for (i in c(1,2,3))
        cat(paste0("track Subtrack", i, "\n",
                   "type bigWig\n",
                   "shortLabel ", shortLabel[i], "\n",
                   "longLabel ", longLabel[i], "\n",
                   "parent CompositeTrack\n",
                   "graphType points\n",
                   "visibility full\n",
                   "bigDataUrl ", bigDataUrl[i], "\n",
                   "color ", color[i], "\n\n"),
            file=file.path(assembly_dir, 'trackDbFile.txt'),
            append=TRUE)
                   
    #plot significant region
    if (no_bed==FALSE){
        appendBedSuperTrack("SuperBedTrack",
                            "multiseq_signal",
                            "multiseq signal",
                            "multiseq_bed_file.bb",
                            "multiseq_signal",
                            paste0("multiseq signal ",fra,"sd"),
                            "255,0,0",
                            out_file=file.path(assembly_dir, "trackDbFile.txt"))
    }
    printGoToMessage(hub_name, assembly, hub_dir, http_address, res$region)
}
