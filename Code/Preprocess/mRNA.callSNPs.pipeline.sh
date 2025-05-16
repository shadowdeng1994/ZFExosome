#!/bin/bash

set -euo pipefail

#mkdir -p rawdata cleandata/{trim_galore,callSNP_gatk,featurecount} cleandata/STAR/{mapping,dedup,splitN,cov}
#for file in `ls`; do new=`echo $file | awk -F "-" '{OFS="_"}{print $3,$4,$5}'`; mv $file $new; done

#ls rawdata/*fastq.gz | awk -F "/" '{print $2}' | awk -F "_c" '{print $1}'|sort|uniq >sample_id.txt

##################################################
## trim_galore
for id in `cat sample_id.txt`
do
	trim_galore --phred33 -q 25 --length 35 --stringency 3 --fastqc --paired --max_n 3 -o ./cleandata/trim_galore rawdata/${id}_R1_001.fastq.gz rawdata/${id}_R2_001.fastq.gz &
done
wait
echo "all samples have been trimmed"

##################################################
## mapping
split -l 3 sample_id.txt -d -a 3 tmpid

ls tmpid* |while read file
do
	for id in `cat $file`
	do 
		STAR --runThreadN $1 --genomeDir ~/projects/chimera/genome/star_index \
        	--readFilesIn cleandata/trim_galore/${id}_R1_001_val_1.fq.gz cleandata/trim_galore/${id}_R2_001_val_2.fq.gz --readFilesCommand zcat \
        	--outFileNamePrefix cleandata/STAR/mapping/${id}_ \
        	--outSAMtype BAM SortedByCoordinate \
        	--outSAMattrRGline ID:$id SM:$id PL:illumina \
        	--twopassMode Basic --twopass1readsN -1 --sjdbOverhang 149 --limitBAMsortRAM 41143265264 &
    	done
    	wait
    	echo "mapping done"
done
##################################################
## markdup
for id in `cat sample_id.txt`
do
	gatk4 MarkDuplicates --REMOVE_DUPLICATES -I cleandata/STAR/mapping/${id}_Aligned.sortedByCoord.out.bam -O cleandata/STAR/dedup/$id.dedup.bam -M cleandata/STAR/dedup/$id.metrics --CREATE_INDEX &
done
wait
echo "dedup done"

##################################################
## splitN
for id in `cat sample_id.txt`
do
	gatk4 SplitNCigarReads -R ~/projects/chimera/genome/Danio_rerio.GRCz11.fa -I cleandata/STAR/dedup/$id.dedup.bam -O cleandata/STAR/splitN/$id.dedup.split.bam &
done
wait
echo "splitN done"

##################################################
## gatk call SNPs
for id in `cat sample_id.txt`
do
	sh callSNPs.chimera.sh cleandata/STAR/splitN/$id.dedup.split.bam $id
done
wait
echo " SNPs calling done"


###################################################
## featurecounts
featureCounts -T 28 -p -t exon -g gene_id -a ~/projects/chimera/genome/Danio_rerio.GRCz11.gtf -o cleandata/featurecount/all.id.txt cleandata/STAR/dedup/*.bam

###################################################
## coverage
for id in `cat sample_id.txt`
do
	bedtools genomecov -bga -split -ibam cleandata/STAR/dedup/${id}.dedup.bam > cleandata/STAR/cov/${id}.cov && echo "${id} coverage finish \t" &
done







