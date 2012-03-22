#!/bin/sh
	
########################################################
###### 	CNV ANNOTATION FOR TUMOR/NORMAL PAIR WHOLE GENOME ANALYSIS PIPELINE

######		Program:			annotation.CNV.sh
######		Date:				11/09/2011
######		Summary:			Annotates CNVNATOR and SEGSEQ outputs
######		Input 
######		$1	=	structural directory
######		$2	=	/path/to/run_info.txt
########################################################

if [ $# != 3 ]
then
    echo "\nUsage: </path/to/output dir> </path/to/run_info.txt>";
else
    set -x
    echo `date`
    output_dir=$1
    run_info=$2
    report_dir=$3
#SGE_TASK_ID=1
    
########################################################	
######		Reading run_info.txt and assigning to variables

    input=$( cat $run_info | grep -w '^INPUT_DIR' | cut -d '=' -f2)
    tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2)
    sample_info=$( cat $run_info | grep -w '^SAMPLE_INFO' | cut -d '=' -f2)
    email=$( cat $run_info | grep -w '^EMAIL' | cut -d '=' -f2)
    script_path=$( cat $tool_info | grep -w '^WHOLEGENOME_PATH' | cut -d '=' -f2 )
    bedtools=$( cat $tool_info | grep -w '^BEDTOOLS' | cut -d '=' -f2 )
    sample=$(cat $run_info | grep -w '^SAMPLENAMES' | cut -d '=' -f2 | tr ":" "\n" | head -n $SGE_TASK_ID | tail -n 1) 
    group=$(cat $run_info | grep -w '^GROUPNAMES' | cut -d '=' -f2 | tr ":" "\n" | head -n $SGE_TASK_ID | tail -n 1) 
    groups=$( cat $run_info | grep -w '^GROUPNAMES' | cut -d '=' -f2)
    master_gene_file=$( cat $tool_info | grep -w '^MASTER_GENE_FILE' | cut -d '=' -f2 )
    multi_sample=$( cat $run_info | grep -w '^MULTISAMPLE' | cut -d '=' -f2)
    sample_info=$( cat $run_info | grep -w '^SAMPLE_INFO' | cut -d '=' -f2)
    chrs=$( cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2)
    chrIndexes=$( echo $chrs | tr ":" "\n" )
    PATH=$bedtools/:$PATH
##############################################################		
    CNV_dir=$output_dir
            
    if [ $multi_sample != "YES" ]
    then
	echo "Single sample"
        ### preparing cnvnator files
        cnvnator=$CNV_dir
        touch $cnvnator/$sample.cnv.raw.del.vcf $cnvnator/$sample.cnv.raw.dup.vcf $cnvnator/$sample.cnv.filter.del.vcf $cnvnator/$sample.cnv.filter.dup.vcf $cnvnator/$sample.del.bed $cnvnator/$sample.dup.bed 
        
        if [ ! -s $cnvnator/$sample.cnv.vcf ]
        then
            echo "ERROR: annotation.CNV.sh file $cnvnator/$sample.cnv.vcf is empty "
            exit 1;
        fi
        
        if [ ! -s $cnvnator/$sample.cnv.filter.vcf ]
        then
            echo "ERROR: annotation.CNV.sh file $cnvnator/$sample.cnv.filter.vcf is empty "
            exit 1;
        fi
        cat $cnvnator/$sample.cnv.vcf | awk '$0 !~ /#/' | grep DEL >> $cnvnator/$sample.cnv.raw.del.vcf
        cat $cnvnator/$sample.cnv.vcf | awk '$0 !~ /#/' | grep DUP >> $cnvnator/$sample.cnv.raw.dup.vcf
        cat $cnvnator/$sample.cnv.filter.vcf | awk '$0 !~ /#/' | grep DEL >> $cnvnator/$sample.cnv.filter.del.vcf
        cat $cnvnator/$sample.cnv.filter.vcf | awk '$0 !~ /#/' | grep DUP >> $cnvnator/$sample.cnv.filter.dup.vcf
        ### merging per chromosome file for del and dup

        cat $cnvnator/$sample.cnv.filter.del.vcf | tr ";" "\t" | tr "=" "\t" | tr ":" "\t" | awk '{print $1"\t"$2"\t"$15"\t""cnvnator_DEL""\t"$26}' > $cnvnator/$sample.del.bed
        cat $cnvnator/$sample.cnv.filter.dup.vcf | tr ";" "\t" | tr "=" "\t" | tr ":" "\t" | awk '{print $1"\t"$2"\t"$15"\t""cnvnator_DUP""\t"$26}' > $cnvnator/$sample.dup.bed
        
        touch $cnvnator/$sample.cnvnator.bed
        cat $cnvnator/$sample.del.bed $cnvnator/$sample.dup.bed >> $cnvnator/$sample.cnvnator.bed
        $bedtools/intersectBed -b $cnvnator/$sample.cnvnator.bed -a $master_gene_file -wb > $cnvnator/$sample.cnvnator.intersect.bed
        cat $cnvnator/$sample.cnvnator.intersect.bed | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$7"\t"$8"\t"$10"\t"$9}' > $cnvnator/$sample.cnvnator.intersect.annotated.bed
        $bedtools/sortBed -i $cnvnator/$sample.cnvnator.intersect.annotated.bed > $cnvnator/$sample.cnvnator.intersect.annotated.sorted.bed
        
        if [ ! -s $cnvnator/$sample.cnvnator.intersect.annotated.sorted.bed ]
        then
            echo " ERROR: annotation.CNV.sh file failed for $sample"
        fi
        ###  generating per sample CNV annotation files
        touch $report_dir/$sample.CNV.annotated.txt
        echo -e "Chr\tGene_Start\tGene_Stop\tGene\tStrand\tCNV_Start\tCNV_Stop\tCNV_Count\tCNV_Type" >> $report_dir/$sample.CNV.annotated.txt
        cat $cnvnator/$sample.cnvnator.intersect.annotated.sorted.bed >> $report_dir/$sample.CNV.annotated.txt
        
        if [ -s $report_dir/$sample.CNV.annotated.txt ]
        then
            ### removing intermediate files
            rm $cnvnator/$sample.del.bed $cnvnator/$sample.dup.bed 
            rm $cnvnator/$sample.cnvnator.bed $cnvnator/$sample.cnvnator.intersect.bed $cnvnator/$sample.cnvnator.intersect.annotated.bed $cnvnator/$sample.cnvnator.intersect.annotated.sorted.bed 
# rm $cnvnator/$sample.cnv.raw.del.vcf $cnvnator/$sample.cnv.raw.dup.vcf $cnvnator/$sample.cnv.filter.del.vcf $cnvnator/$sample.cnv.filter.dup.vcf
        else
            echo " ERROR: annotation.CNV.sh file failed for $sample "
        fi    
    else
        echo "Multi sample"
        samples=$( cat $sample_info | grep -w "^$group" | cut -d '=' -f2 )
        let num_tumor=`echo $samples|tr " " "\n"|wc -l`-1
        tumor_list=`echo $samples | tr " " "\n" | tail -$num_tumor`
        cnvnator=$CNV_dir
        for tumor in $tumor_list
        do
            touch $cnvnator/$group.$tumor.cnv.raw.del.vcf $cnvnator/$group.$tumor.cnv.raw.dup.vcf $cnvnator/$group.$tumor.cnv.filter.del.vcf $cnvnator/$group.$tumor.cnv.filter.dup.vcf $cnvnator/$group.$tumor.del.bed $cnvnator/$group.$tumor.dup.bed 

			if [ ! -s $cnvnator/$group.$tumor.cnv.vcf ]
			then
				echo "ERROR: annotation.CNV.sh file $cnvnator/$group.$tumor.cnv.vcf is empty "
				exit 1;
			fi

			if [ ! -s $cnvnator/$group.$tumor.cnv.filter.vcf ]
			then
				echo "ERROR: annotation.CNV.sh file $cnvnator/$group.$tumor.cnv.filter.vcf is empty "
				exit 1;
			fi

			cat $cnvnator/$group.$tumor.cnv.vcf | awk '$0 !~ /#/' | grep DEL >> $cnvnator/$group.$tumor.cnv.raw.del.vcf
			cat $cnvnator/$group.$tumor.cnv.vcf | awk '$0 !~ /#/' | grep DUP >> $cnvnator/$group.$tumor.cnv.raw.dup.vcf
			cat $cnvnator/$group.$tumor.cnv.filter.vcf | awk '$0 !~ /#/' | grep DEL >> $cnvnator/$group.$tumor.cnv.filter.del.vcf
			cat $cnvnator/$group.$tumor.cnv.filter.vcf | awk '$0 !~ /#/' | grep DUP >> $cnvnator/$group.$tumor.cnv.filter.dup.vcf
			### merging per chromosome file for del and dup

			cat $cnvnator/$group.$tumor.cnv.filter.del.vcf | tr ";" "\t" | tr "=" "\t" | tr ":" "\t" | awk '{print $1"\t"$2"\t"$15"\t""segseq_DEL""\t"$26}' > $cnvnator/$group.$tumor.del.bed
			cat $cnvnator/$group.$tumor.cnv.filter.dup.vcf | tr ";" "\t" | tr "=" "\t" | tr ":" "\t" | awk '{print $1"\t"$2"\t"$15"\t""segseq_DUP""\t"$26}' > $cnvnator/$group.$tumor.dup.bed

			touch $cnvnator/$group.$tumor.cnvnator.bed
			cat $cnvnator/$group.$tumor.del.bed $cnvnator/$group.$tumor.dup.bed >> $cnvnator/$group.$tumor.cnvnator.bed
			$bedtools/intersectBed -b $cnvnator/$group.$tumor.cnvnator.bed -a $master_gene_file -wb > $cnvnator/$group.$tumor.cnvnator.intersect.bed
			cat $cnvnator/$group.$tumor.cnvnator.intersect.bed | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$7"\t"$8"\t"$10"\t"$9}' > $cnvnator/$group.$tumor.cnvnator.intersect.annotated.bed
			$bedtools/sortBed -i $cnvnator/$group.$tumor.cnvnator.intersect.annotated.bed > $cnvnator/$group.$tumor.cnvnator.intersect.annotated.sorted.bed

			if [ ! -s $cnvnator/$group.$tumor.cnvnator.intersect.annotated.sorted.bed ]
			then
				echo " ERROR: annotation.CNV.sh file failed for $sample"
			fi
			###  generating per sample CNV annotation files
			touch $report_dir/$group.$tumor.CNV.annotated.txt
			echo -e "Chr\tGene_Start\tGene_Stop\tGene\tStrand\tCNV_Start\tCNV_Stop\tCNV_Count\tCNV_Type" >> $report_dir/$group.$tumor.CNV.annotated.txt
			cat $cnvnator/$group.$tumor.cnvnator.intersect.annotated.sorted.bed >> $report_dir/$group.$tumor.CNV.annotated.txt

			if [ -s $report_dir/$group.$tumor.CNV.annotated.txt ]
			then
			### removing intermediate files
			rm $cnvnator/$group.$tumor.del.bed $cnvnator/$group.$tumor.dup.bed 
			rm $cnvnator/$group.$tumor.cnvnator.bed $cnvnator/$group.$tumor.cnvnator.intersect.bed $cnvnator/$group.$tumor.cnvnator.intersect.annotated.bed $cnvnator/$group.$tumor.cnvnator.intersect.annotated.sorted.bed 
			# rm $cnvnator/$sample.cnv.raw.del.vcf $cnvnator/$sample.cnv.raw.dup.vcf $cnvnator/$sample.cnv.filter.del.vcf $cnvnator/$sample.cnv.filter.dup.vcf
			else
				echo " ERROR: annotation.CNV.sh file failed for $sample "
			fi  
		done
	fi
    echo `date`
fi

