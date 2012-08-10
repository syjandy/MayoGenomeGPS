#!/bin/sh

##	INFO
##	script is used to submit batch scripts to locally installed sift database

###############################
#	$1		=		sift output directory	
#	$2		=		sample name
#	$3		=		SNV input file
#	$4		=		directory for input file
#	$5		=		chromosome
#	$6		=		run_info file
#################################

if [ $# -le 3 ];
then
    echo "Usage:<sift dir> <input dir><sample><run info>";
else
    set -x
    echo `date` 
    sift=$1
    input=$2
    sample=$3
    run_info=$4
    if [ $5 ]
    then
		prefix=$5
    fi	
    #SGE_TASK_ID=22
	tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2)
    version=$( cat $run_info | grep -w '^VERSION' | cut -d '=' -f2)
    sift_ref=$( cat $tool_info | grep -w '^SIFT_REF' | cut -d '=' -f2) 
    sift_path=$( cat $tool_info | grep -w '^SIFT' | cut -d '=' -f2) 
    script_path=$( cat $tool_info | grep -w '^WHOLEGENOME_PATH' | cut -d '=' -f2 )
    analysis=$( cat $run_info | grep -w '^ANALYSIS' | cut -d '=' -f2| tr "[A-Z]" "[a-z]")
    run_num=$( cat $run_info | grep -w '^OUTPUT_FOLDER' | cut -d '=' -f2)
    flowcell=`echo $run_num | awk -F'_' '{print $NF}' | sed 's/.\(.*\)/\1/'`
    chr=$(cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2 | tr ":" "\n" | head -n $SGE_TASK_ID | tail -n 1)
    java=$( cat $tool_info | grep -w '^JAVA' | cut -d '=' -f2 )
    threads=$( cat $tool_info | grep -w '^THREADS' | cut -d '=' -f2) 
    ### update dashboard
    $script_path/dashboard.sh $sample $run_info Annotation started
    
    if [ $5 ]
    then
        sam=$prefix.$sample
    else
        sam=$sample
    fi	
    ### hard coded
    snv_file=$sam.variants.chr$chr.SNV.filter.i.c.vcf
    if [ ! -s $input/$snv_file ]
    then
        $script_path/errorlog.sh $input/$snv_file sift.sh ERROR "not found"
    fi
    
    num_snvs=`cat $input/$snv_file | awk '$0 !~ /^#/' | wc -l`
    #sift acceptable format 
    
    if [[ $num_snvs == 0 || $chr -eq 'M' ]]
    then
        touch $sift/${sample}_chr${chr}_predictions.tsv
        echo -e "Coordinates\tCodons\tTranscript ID\tProtein ID\tSubstitution\tRegion\tdbSNP ID\tSNP Type\tPrediction\tScore\tMedian Info\t# Seqs at position\tGene ID\tGene Name\tOMIM Disease\tAverage Allele Freqs\tUser Comment" > $sift/${sam}_chr${chr}_predictions.tsv
    else
        cat $input/$snv_file | awk '$0 !~ /^#/' | sed -e '/chr/s///g' | awk '{print $1","$2",1,"$4"/"$5}' > $sift/$snv_file.sift
        a=`pwd`
        #running SIFT for each sample
        cd $sift_path
        $script_path/parallel.sift.pl $threads $sift/$snv_file.sift $sift_ref $sift_path/ $sift/${sam}_chr${chr}_predictions.tsv $sift/
        # sift inconsistent results flips alt base by itself getting rid of wrong calls from sift output
		perl $script_path/sift.inconsistent.pl $sift/${sam}_chr${chr}_predictions.tsv $sift/$snv_file.sift
        mv $sift/${sam}_chr${chr}_predictions.tsv_mod $sift/${sam}_chr${chr}_predictions.tsv
        rm $sift/$snv_file.sift
        cd $a
    fi
    if [ ! -s $sift/${sam}_chr${chr}_predictions.tsv ]
    then
        $script_path/errorlog.sh $sift/${sam}_chr${chr}_predictions.tsv sift.sh ERROR "failed to create" 
		exit 1;
    fi
    echo `date`
fi	
