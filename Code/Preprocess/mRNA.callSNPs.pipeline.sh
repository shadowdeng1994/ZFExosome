#!/bin/bash

set -euo pipefail
SAMPLE_ID_LIST=$1

mkdir -p rawdata cleandata/{trim_galore,callSNP_gatk,featurecount} cleandata/STAR/{mapping,dedup,splitN,cov}
for file in `ls`; do new=`echo $file | awk -F "-" '{OFS="_"}{print $3,$4,$5}'`; mv $file $new; done

ls rawdata/*fastq.gz | awk -F "/" '{print $2}' | awk -F "_c" '{print $1}'|sort|uniq >sample_id.txt

#################################################
## trim_galore
export MAX_JOBS=6
export THREADS_PER_JOB=4

cat "${SAMPLE_ID_LIST}" |xargs -I {id} -P "${MAX_JOBS}" bash -c '
	trim_galore --phred33 \
		-q 25 \
		--length 35 \
		--stringency 3 \
		--fastqc \
		--paired \
		--max_n 3 \
		--cores "${THREADS_PER_JOB}"\
		-o ./cleandata/trim_galore \
		rawdata/{id}_R1_001.fastq.gz rawdata/{id}_R2_001.fastq.gz
'


##################################################
## mapping
export MAX_JOBS=3
export THREADS_PER_JOBS=8
export SORT_RAM=30000000000
export GENOME_DIR="/home/xianghm/projects/chimera/genome/star_index"

echo “========== 开始STAR 序列比对（并发数：${MAX_JOBS}）==========”

cat ${SAMPLE_ID_LIST} | xargs -I {id} -P ${MAX_JOBS} bash -c '
	echo " -> 正在使用STAR比对样本：{id}"

	STAR --runThreadN ${THREADS_PER_JOBS} --genomeDir ${GENOME_DIR} \
		--readFilesIn cleandata/trim_galore/{id}_1_val_1.fq.gz cleandata/trim_galore/{id}_2_val_2.fq.gz \
		--readFilesCommand zcat \
                --outFileNamePrefix cleandata/STAR/mapping/{id}_ \
                --outSAMtype BAM SortedByCoordinate \
                --outSAMattrRGline ID:{id} SM:{id} PL:illumina \
                --twopassMode Basic \
		--twopass1readsN -1 \
		--sjdbOverhang 149 \
		--limitBAMsortRAM ${SORT_RAM} \
		--outBAMsortingThreadN 6 \
		>cleandata/STAR/mapping/{id}_star.log 2>&1
'

echo "========== STAR 比对全部完成 =========="


## markdup
# markduplicates 
MD_PARALLEL=6
MD_JAVA="-Xmx16G -XX:ParallelGCThreads=2"
echo "========== 开始 MarkDuplicates (并发数: ${MD_PARALLEL}) =========="
cat ${SAMPLE_ID_LIST} | xargs -I {id} -P ${MD_PARALLEL} bash -c "
	echo ' -> 正在去重样本：{id}'
	gatk4 --java-options '${MD_JAVA}' MarkDuplicates \
		--REMOVE_DUPLICATES \
		-I cleandata/STAR/mapping/{id}_Aligned.sortedByCoord.out.bam \
		-O cleandata/STAR/dedup/{id}.dedup.bam \
		-M cleandata/STAR/dedup/{id}.metrics \
		--CREATE_INDEX \
		> cleandata/STAR/dedup/{id}_md.log 2>&1
"
echo "========== MarkDuplicates 全部完成 =========="


##################################################
## splitN
SP_PARALLEL=10
SP_JAVA="-Xmx8G -XX:ParallelGCThreads=2"

echo "========== 开始 SplitNCigarReads (并发数: ${SP_PARALLEL}) =========="
cat ${SAMPLE_ID_LIST} | xargs -I {id} -P ${SP_PARALLEL} bash -c "
	echo '  -> 正在拆分跨内含子 Reads 样本: {id}'
	gatk4 --java-options '${SP_JAVA}' SplitNCigarReads \
		-R /home/xianghm/projects/chimera/genome/Danio_rerio.GRCz11.fa \
		-I cleandata/STAR/dedup/{id}.dedup.bam \
		-O cleandata/STAR/splitN/{id}.dedup.split.bam \
		> cleandata/STAR/splitN/{id}_split.log 2>&1
"
echo "========== SplitNCigarReads 全部完成 =========="

##################################################
## gatk call SNPs
for id in `cat ${SAMPLE_ID_LIST}`
do
	sh call_chimera.sh cleandata/STAR/splitN/$id.dedup.split.bam $id
done
wait
echo " SNPs calling done"


###################################################
## featurecounts
featureCounts -T 28 -p -t exon -g gene_id -a ~/projects/chimera/genome/Danio_rerio.GRCz11.gtf -o cleandata/featurecount/all.id.txt cleandata/STAR/dedup/*.bam

###################################################
## coverage
export MAX_PARALLEL=6
export OUT_DIR="cleandata/STAR/cov"

echo "========== starting calculate coverage （parallel: ${MAX_PARALLEL}) =========="
cat ${SAMPLE_ID_LIST} |xargs -I {id} -P ${MAX_PARALLEL} bash -c '
	echo " -> 正在处理样本：{id}" 

	bedtools genomecov -bga -split \
		-ibam cleandata/STAR/dedup/{id}.dedup.bam \
		> ${OUT_DIR}/{id}.cov
'
echo "========== coverage calculation of all samples has been completed =========="  
