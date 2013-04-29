#!/bin/bash

####
# samse.sh (bwa alignment)
# 4/24/2013
# script to run samse command 
# baheti.saurabh@mayo.edu
####

### function
function check_variable()	{
	message=$1
	if [[ "$2" == "" ]] 
	then 
		echo "$message is not set correctly."
		exit 1
	fi		
}	
if [ $# =! 5 ]
then
	echo -e "\nscript to run samse on a input file \
		\nUsage: ./fastqc.sh <sample name> <sai file for read1><full path to fastq file> <full path to output bam file> \
			<tool info file>"
	exit 1;
fi
START=$(date +%s)

sample=$1
sai_R1=$2
fastq_R1=$3
outputbam=$4
tool_info=$5


bwa=$( cat $tool_info | grep -w '^BWA' | cut -d '=' -f2)
check_variable "$tool_info:BWA" $bwa
center=$( cat $tool_info | grep -w '^CENTER' | cut -d '=' -f2 )
check_variable "$tool_info:CENTER" $center
platform=$( cat $tool_info | grep -w '^PLATFORM' | cut -d '=' -f2 )
check_variable "$tool_info:PLATFORM" $platform
genome_bwa=$( cat $tool_info | grep -w '^BWA_REF' | cut -d '=' -f2)	
check_variable "$tool_info:BWA_REF" $genome_bwa
samtools=$( cat $tool_info | grep -w '^SAMTOOLS' | cut -d '=' -f2)
check_variable "$tool_info:SAMTOOLS" $samtools

$bwa/bwa samse -r "@RG\tID:$sample\tSM:$sample\tLB:$sample\tPL:$platform\tCN:$center" \
	$genome_bwa $sai_R1 $fastq_R1 | $samtools/samtools view -bS - > $outputbam

END=$(date +%s)
DIFF=$(( $END - $START ))
echo "samse for $sample took $DIFF seconds"		