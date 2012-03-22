#!/bin/sh

########################################################
###### 	Merges variants from vcf files by chromosome

######		Program:			merge_variant_group.sh
######		Date:				12/13/2011
######		Summary:			Using PICARD to sort and mark duplicates in bam 
######		Input files:		$1	=	/path/to/input directory
######					$2	=	sample name
######					$3	=	/path/to/run_info.txt
########################################################

if [ $# != 4 ];
then
    echo "Usage: </path/to/input directory> <sample name> </path/to/run_info.txt>";
else
    set -x
    echo `date`
    input=$1
    sample=$2
    out=$3
    run_info=$4
    
########################################################	
######		Reading run_info.txt and assigning to variables
    tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2)
    picard=$( cat $tool_info | grep -w '^PICARD' | cut -d '=' -f2 ) 
    java=$( cat $tool_info | grep -w '^JAVA' | cut -d '=' -f2)
    chrs=$( cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2 | tr ":" "\n" )
    ref=$( cat $tool_info | grep -w '^REF_GENOME' | cut -d '=' -f2)
    gatk=$( cat $tool_info | grep -w '^GATK' | cut -d '=' -f2)
    script_path=$( cat $tool_info | grep -w '^WHOLEGENOME_PATH' | cut -d '=' -f2 )

    output=$( cat $run_info | grep -w '^BASE_OUTPUT_DIR' | cut -d '=' -f2)
    PI=$( cat $run_info | grep -w '^PI' | cut -d '=' -f2)
    tool=$( cat $run_info | grep -w '^TYPE' | cut -d '=' -f2 | tr "[A-Z]" "[a-z]" )
    run_num=$( cat $run_info | grep -w '^OUTPUT_FOLDER' | cut -d '=' -f2)
    errorfile=$output/$PI/$tool/$run_num/error.log
    
########################################################	

    inputargs=""
    for i in $chrs
    do
      inputfile=$input/$sample/$sample.variants.chr$i.raw.vcf 
      if [ ! -s $inputfile ]
      then	
          echo "ERROR :merge_variant_single_chr. Variant file for sample $sample, chromosome $i: $inputfile does not exist "
          exit 1
      else
          inputargs="-V $inputfile "$inputargs
      fi
    done

    $java/java -Xmx2g -Xms512m -jar $gatk/GenomeAnalysisTK.jar \
    -R $ref \
    -et NO_ET \
    -T CombineVariants \
    $inputargs \
    -o $out/$sample.variants.raw.vcf

    if [ ! -s $out/$sample.variants.raw.vcf ]
    then		
        echo "ERROR :merge_variant_single_chr, CombineVariants File: $input/$sample.variants.raw.vcf was not created "
        exit 1
    fi

    if [ $tool == "whole_genome" ]
    then
        $script_path/filter_variant_vqsr.sh $out/$sample.variants.raw.vcf $out/$sample.variants.filter.vcf BOTH $run_info
    elif [ $tool == "exome" ]
    then
        ## appy hard filters to the vcf variant file
        $java/java -Xmx2g -Xms512m -jar $gatk/GenomeAnalysisTK.jar \
        -R $ref \
        -et NO_ET \
        -l INFO \
        -T VariantFiltration \
        -V $out/$sample.variants.raw.vcf \
        -o $out/$sample.variants.filter.vcf \
        --clusterSize 10 \
        --filterExpression "MQ0 >= 4 && ((MQ0 / (1.0 * DP)) > 0.1)" \
        --filterName "HARD_TO_VALIDATE" \
        --filterExpression "QD < 1.5 " \
        --filterName "LowQD"  
    fi
    
    if [ ! -s $out/$sample.variants.filter.vcf ]
    then
        echo "ERROR: hard filters failed to generate the filterd vcf for $sample"
        exit 1
    else
        for i in $chrs
        do
            cat $out/$sample.variants.filter.vcf | awk -v num=chr${i} '$0 ~ /#/ || $1 == num' > $input/$sample/$sample.variants.chr$i.filter.vcf 
        done
    fi  
	echo `date`	
fi  