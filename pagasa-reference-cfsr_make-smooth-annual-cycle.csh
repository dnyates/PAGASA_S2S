#!/bin/tcsh
#SBATCH -J cfsr_sm
#SBATCH -A P48500028
#SBATCH -t 02:00:00
#SBATCH -p dav
#SBATCH -n 1
#SBATCH --mem=50G

### Set TMPDIR as recommended
#setenv TMPDIR /glade/scratch/$USER/temp

setenv project 'pagasa'
setenv indir   /d3/hydrofcst/overtheloop/data/cfsr/pagasa/
#setenv indir   /d3/hydrofcst/overtheloop/data/cfsr/daily/test/
setenv outdir  /d3/hydrofcst/overtheloop/data/cfsr/pagasa/
#setenv outdir  /d3/hydrofcst/overtheloop/data/cfsr/daily/test/

#set varlist = ("refevt" "tas" "tasmin" "tasmax" "netrad" "pr" "ps" "rhum" "windspeed" "u10" "v10")
#foreach var($varlist)
#	ncrcat -O -h -v {$var} -d lat,-5.,25. -d lon,95.,140. {$indir}cfsr_global_*daily.nc {$outdir}{$var}_{$project}_1982-2009_daily.nc
#end

##
## compute daily and monthly annual cycles with distribution information
##
#module load ncl
#ncl cfsr_make-smooth-annual-cycle.ncl;
#wait


##
## cleanup and combine variables into single files for daily and monthly-stats
##

rm $outdir/cfsr_{$project}*stats.nc
cp $outdir/refevt_{$project}_1982-2009_daily-stats.nc 	$outdir/cfsr_{$project}_1982-2009_daily-stats.nc
cp $outdir/refevt_{$project}_1982-2009_monthly-stats.nc	$outdir/cfsr_{$project}_1982-2009_monthly-stats.nc 

set varlist = ("tas" "tasmin" "tasmax" "netrad" "pr" "ps" "rhum" "windspeed" "u10" "v10")
foreach var($varlist)
	ncks -h -A {$outdir}/{$var}_{$project}_1982-2009_daily-stats.nc  	$outdir/cfsr_{$project}_1982-2009_daily-stats.nc
	ncks -h -A {$outdir}/{$var}_{$project}_1982-2009_monthly-stats.nc  	$outdir/cfsr_{$project}_1982-2009_monthly-stats.nc
end

rm $outdir/refevt_{$project}_1982-2009_*
foreach var($varlist)
	rm $outdir/{$var}_{$project}_1982-2009_*
end




#echo "job has completed" | mail -s "CFSR_hourly_to_daily_processing -- done" ammann@ucar.edu

scontrol show job $SLURM_JOB_ID

