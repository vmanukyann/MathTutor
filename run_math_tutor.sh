#!/bin/bash
#$ -q gpu@@mjiang2_l40s
#$ -pe smp 1
#$ -l gpu=1
#$ -N math_tutor_job
#$ -cwd
#$ -j y
#$ -o logs/$JOB_NAME.$JOB_ID.log

# Load required modules (adjust based on your cluster setup)
module load python/3.9  # or whatever Python version you need
module load cuda/12.1   # or appropriate CUDA version

# Activate your virtual environment if you have one
# source /path/to/your/venv/bin/activate

# Run your Python script
python your_script_name.py#!/bin/bash
#$ -q gpu@@mjiang2_l40s
#$ -pe smp 1
#$ -l gpu=1
#$ -N math_tutor_job
#$ -cwd
#$ -j y
#$ -o logs/$JOB_NAME.$JOB_ID.log

# Load required modules (adjust based on your cluster setup)
module load python/3.9  # or whatever Python version you need
module load cuda/12.1   # or appropriate CUDA version

# Activate your virtual environment if you have one
# source /path/to/your/venv/bin/activate

# Run your Python script
python your_script_name.py