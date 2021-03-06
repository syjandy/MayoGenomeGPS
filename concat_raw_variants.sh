#!/bin/bash

if [ $# != 2 ]
then
	echo -e "script to concat per chromosome file to a merged file\nUsage : ./concat_raw_variants.sh </path/to/output folder> </path/to/run info file>"
else
	set -x
	echo `date`
	output_dir=$1
	run_info=$2
	
	tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2)
	samples=$(cat $run_info | grep -w '^SAMPLENAMES' | cut -d '=' -f2| tr ":" " ")
	chrs=$(cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2| tr ":" " ")	
	ref=$( cat $tool_info | grep -w '^REF_GENOME' | cut -d '=' -f2)
	java=$( cat $tool_info | grep -w '^JAVA' | cut -d '=' -f2)
	vcftools=$( cat $tool_info | grep -w '^VCFTOOLS' | cut -d '=' -f2)
	perllib=$( cat $tool_info | grep -w '^PERLLIB_VCF' | cut -d '=' -f2)
	tabix=$( cat $tool_info | grep -w '^TABIX' | cut -d '=' -f2)
	chrs=$(cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2 | tr ":" " ")
	script_path=$( cat $tool_info | grep -w '^WORKFLOW_PATH' | cut -d '=' -f2)
	export PERL5LIB=$PERL5LIB:$perllib
	PATH=$tabix/:$PATH
	var_dir=$output_dir/variants
	
	##SNV merging
	inputargs=""
	indexes=""
	for chr in $chrs
	do
		inputfile=$var_dir/raw.chr$chr.SNV.vcf.gz 
		if [ ! -s $inputfile ]
		then
			$script_path/email.sh $inputfile "not exist" merge_raw_variants.sh $run_info
			touch $inputfile.fix.log
			$script_path/wait.sh $inputfile.fix.log	
		fi
		inputfile_i=$var_dir/raw.chr$chr.SNV.vcf.gz.tbi
		if [ ! -s $inputfile_i ]
		then
			$tabix/tabix -p vcf $inputfile
		fi	
		indexes=$indexes" $inputfile_i"
		inputargs=$inputargs" $inputfile"
	done
	
	$vcftools/bin/vcf-concat $inputargs | $tabix/bgzip > $var_dir/raw.SNV.vcf.gz
	$tabix/tabix -p vcf $var_dir/raw.SNV.vcf.gz
	
	if [ -s $var_dir/raw.SNV.vcf.gz ]
	then
		rm $inputargs
		rm $indexes
	else
		$script_path/errorlog.sh $var_dir/raw.SNV.vcf.gz concat_raw_variants.sh ERROR "failed to create"
		exit 1;
	fi

	### INDEL merging
	inputargs=""
	indexes=""
	for chr in $chrs
	do
		inputfile=$var_dir/raw.chr$chr.INDEL.vcf.gz 
		inputfile_i=$var_dir/raw.chr$chr.INDEL.vcf.gz.tbi 
		indexes=$indexes" $inputfile_i"
		inputargs=$inputargs" $inputfile"
	done
	
	$vcftools/bin/vcf-concat $inputargs | $tabix/bgzip > $var_dir/raw.INDEL.vcf.gz
	$tabix/tabix -p vcf $var_dir/raw.INDEL.vcf.gz
	
	if [ -s $var_dir/raw.INDEL.vcf.gz ]
	then
		rm $inputargs
		rm $indexes
	else
		$script_path/errorlog.sh $var_dir/raw.INDEL.vcf.gz concat_raw_variants.sh ERROR "failed to create"
		exit 1;
	fi	
	echo `date`
fi	
	
	