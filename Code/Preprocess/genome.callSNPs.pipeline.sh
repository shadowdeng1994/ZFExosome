#!/bin/bash

set -euo pipefail

# $1 bwa thread
# $2 samtobam thread

#mkdir -p rawdata cleandata/{callSNP_gatk,trim_galore,bwa_mem_M} 
#for file in `ls`; do new=`echo $file | awk -F "-" '{OFS="_"}{print $3,$4,$5}'`; mv $file $new; done

#ls rawdata/*fastq.gz | awk -F "/" '{print $2}' | awk -F "_c" '{print $1}'|sort|uniq >sample_id.txt

##################################################
## trim_galore
for id in `cat sample_id.txt`
do
	trim_galore --phred33 -q 25 --length 35 --stringency 3 --fastqc --paired --max_n 3 -o ./cleandata/trim_galore rawdata/${id}_combined_R1.fastq.gz rawdata/${id}_combined_R2.fastq.gz &
done
wait
echo "all samples have been trimmed"

##################################################
## mapping
for id in `cat sample_id.txt`
do
	bwa mem -t $1 -M ~/projects/chimera/genome/Danio_rerio.GRCz11.fa cleandata/trim_galore/${id}_combined_R1_val_1.fq.gz cleandata/trim_galore/${id}_combined_R2_val_2.fq.gz -R "@RG\tID:${id}\tLB:${id}\tSM:${id}\tPL:ILLUMINA" >cleandata/bwa_mem_M/${id}.sam
done

##################################################
# sam to sorted bam
for id in `cat sample_id.txt`
do
	samtools view -b -u cleandata/bwa_mem_M/${id}.sam | samtools sort -@ $2 -o cleandata/bwa_mem_M/${id}.sorted.bam&
done
wait
echo "########## mapping done ##########"

for id in `cat sample_id.txt`
do
	FILE=cleandata/bwa_mem_M/${id}.sorted.bam
	if [ -f "$FILE" ]; then
		rm cleandata/bwa_mem_M/${id}.sam
	else
		echo " ${id}.sorted.bam not exists "
	fi
done

##################################################
## markdup
for id in `cat sample_id.txt`
do
	gatk4 MarkDuplicates --REMOVE_DUPLICATES -I cleandata/bwa_mem_M/${id}.sorted.bam -O cleandata/bwa_mem_M/${id}.dedup.bam -M cleandata/bwa_mem_M/$id.metrics --CREATE_INDEX &
done
wait
echo "dedup done"

##################################################
## gatk call SNPs
for id in `cat sample_id.txt`
do
	sh callSNPs.genome.sh cleandata/bwa_mem_M/$id.dedup.bam $id /home/xianghm/projects/chimera/genome_gVCF
done
wait
echo " SNPs calling done"


