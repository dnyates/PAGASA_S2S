#!/usr/bin/bash
#SBATCH -J wrf_exp6
#SBATCH -t 04:00:00
#SBATCH -n 1
#SBATCH --mem=100G


# CFS download

./pagasa-get-cfs_from-ncep.bash;
wait

#ncl pagasa-forecast-cfs_make-daily.ncl;
#wait

#ncl pagasa-forecast-cfs_make-monthly.ncl;
#wait

#./pagasa-forecast-cfs_make-9month-ensemble.csh;
#wait

#./pagasa-forecast-cfs_make-60day-ensemble.csh;
#wait


 