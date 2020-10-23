#!/bin/tcsh

if  ($#argv == 3) then
	echo "got date from command line"
	set year        = $argv[1]
	set month       = $argv[2]
	set d           = $argv[3]
	set day         = $argv[1]$argv[2]$argv[3]
	set YM          = $argv[1]$argv[2]
else
	echo "determine date automatically : use today"
	set year        = `date +%Y`
	set month       = `date +%m`
	set d           = `date +%d`
	set day         = `date +%Y%m%d`
	set YM          = {$year}{$month}
endif

setenv	project		'pagasa'
setenv	cfsyear		$year
setenv	cfsmonth	$month
setenv	cfsday		$d

setenv	indir 		'/gpfs/data/WRFdriver/cfs/'
#setenv	indir 		'/gpfs/home/ncar/test/WRFdriver/cfs/'
set	  	daydir    = {$indir}$year/$YM/$day
echo 	$daydir

##
## compute daily and monthly annual cycles with distribution information
##
#module load ncl
ncl pagasa-forecast-cfs_make-60day-ensemble.ncl;
wait


##
## cleanup and combine variables into single files for daily and monthly-stats
##
set varlist = ( "tas" "tasmin" "tasmax" "pr" "ps" "rhum" "netrad" "windspeed" "u10" "v10")
rm -rf {$daydir}/cfsv2_{$project}*_60day-ensemble.nc

set outfile = `echo {$daydir}/refevt_{$project}_*_60day-ensemble.nc | sed "s/refevt/cfsv2/g"`
cp {$daydir}/refevt_{$project}_*_60day-ensemble.nc $outfile
foreach var($varlist)
	ncks -h -A {$daydir}/{$var}_{$project}_*_60day-ensemble.nc  $outfile
end

rm -rf $daydir/refevt_{$project}_*_60day-ensemble.nc
foreach var($varlist)
	rm -rf $daydir/{$var}_{$project}_*_60day-ensemble.nc
end





