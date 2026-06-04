#!/bin/bash

set -euo pipefail
SAMPLE_ID_LIST=$1

mkdir -p rawdata cleandata/callSNP_gatk cleandata/trim_galore cleandata/bwa_mem_M 
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
export MAX_JOBS=4
export THREAD_PER_JOB=4
export GENOME_REF="$HOME/projects/chimera/genome/Danio_rerio.GRCz11.fa"

cat "${SAMPLE_ID_LIST}" |xargs -I {id} -P "${MAX_JOBS}" bash -c '
	bwa mem -t "${THREAD_PER_JOB}" -M \
		"${GENOME_FA}" \
		cleandata/trim_galore/{id}_combined_R1_val_1.fq.gz \
		cleandata/trim_galore/{id}_combined_R2_val_2.fq.gz \
		-R "@RG\tID:{id}\tLB:{id}\tSM:{id}\tPL:ILLUMINA" >cleandata/bwa_mem_M/{id}.sam
'

##################################################
# sam to sorted bam
export MAX_JOBS=3
export THREAD_PER_JOB=8
export MEM_PER_THREAD="4G"

cat "${SAMPLE_ID_LIST}" |xargs -I {id} -P "${MAX_JOBS}" bash -c '
	id="{id}"
	sam_file="cleandata/bwa_mem_M/${id}.sam"
	bam_file="cleandata/bwa_mem_M/${id}.sorted.bam

	samtools sort -@ "${THREAD_PER_JOB}" \
		-m "${MEM_PER_THREAD}" \
		-o "${bam_file}" \
		"${sam_file}" > "${bam_file}.log" 2>&1

	# check sorted bam file and delete sam file
	if [ $? -eq 0 ] && [ -s "${bam_file}" ]; then
        	rm -f "${sam_file}"
        	rm -f "${bam_file}.log"
    	else
        	echo "${sam_file} failed"
    	fi
'
echo "[$(date "+%H:%M:%S")] ########## mapping and sorting done ##########"
##################################################
## markdup
MD_PARALLEL=6
MD_JAVA="-Xmx16G -XX:ParallelGCThreads=2"
echo "========== 开始 MarkDuplicates (并发数: ${MD_PARALLEL}) =========="
cat ${SAMPLE_ID_LIST} | xargs -I {id} -P ${MD_PARALLEL} bash -c "
        echo ' -> 正在去重样本：{id}'
        gatk4 --java-options '${MD_JAVA}' MarkDuplicates \
                --REMOVE_DUPLICATES \
                -I cleandata/bwa_mem_M/{id}.sorted.bam \
                -O cleandata/bwa_mem_M/{id}.dedup.bam \
                -M cleandata/bwa_mem_M/{id}.metrics \
                --CREATE_INDEX \
                > cleandata/bwa_mem_M/{id}_md.log 2>&1
"
echo "========== MarkDuplicates 全部完成 =========="

##################################################
## gatk call SNPs
for id in `cat ${SAMPLE_ID_LIST}`
do
	sh call_genome.sh cleandata/bwa_mem_M/$id.dedup.bam $id
done
wait
echo " SNPs calling done"
