#!/bin/tcsh

if  ($#argv == 3) then
	echo "got date"
    set year        = $argv[1]
	set month       = $argv[2]
	set d           = $argv[3]
	set day         = $argv[1]$argv[2]$argv[3]
	set YM          = $argv[1]$argv[2]
else
	echo "determine date automatically : today"
	set year        = `date +%Y`
	set month       = `date +%m`
	set d           = `date +%d`
	set day         = `date +%Y%m%d`
	set YM          = {$year}{$month}
endif

setenv  project         'pagasa'
setenv  cfsyear         $year
setenv  cfsmonth        $month
setenv  cfsday          $d
												  
setenv	indir 			'/gpfs/data/WRFdriver/cfs/'
#setenv	indir 			'/gpfs/home/ncar/test/WRFdriver/cfs/'
set	  	daydir 		   = {$indir}/$year/$YM/$day
echo   $daydir

##
## compute daily and monthly annual cycles with distribution information
##
#module load ncl
ncl pagasa-forecast-cfs_make-9month-ensemble.ncl;
wait

echo 'done with ncl'
##
## cleanup and combine variables into single files for daily and monthly-stats
##
set varlist = ("et5mm" "tas" "tasmin" "tasmax" "pr" "rhum" "windspeed" "u10" "v10")
echo 'now clean up'
rm -rf {$daydir}/cfsv2_{$project}_*_9month-ensemble.nc

set outfile = `echo {$daydir}/refevt_{$project}_*_9month-ensemble.nc | sed "s/refevt/cfsv2/g"`
cp {$daydir}/refevt_{$project}_*_9month-ensemble.nc $outfile
foreach var($varlist)
	ncks -h -A {$daydir}/{$var}_{$project}_*_9month-ensemble.nc  $outfile
end

rm -rf $daydir/refevt_{$project}_*_9month-ensemble.nc
foreach var($varlist)
	rm -rf $daydir/{$var}_{$project}_*_9month-ensemble.nc
end





