#!/bin/tcsh
#SBATCH -J cfsr2002
#SBATCH -A NRAL0002
#SBATCH -t 24:00:00
#SBATCH -p dav
#SBATCH -n 1
#SBATCH --mem=30G

#
# LSF Batch Script to Download CFSR
#

#./cfsr_download.bash

module load ncl

set indir  = "/glade/scratch/ammann/CFSR"

set project = "pagasa"
set latmin =  -5.
set latmax =  25.
set lonmin =  95.
set lonmax = 140.

set var = (tas tasmin tasmax pr ps netrad refevt windspeed rhum u10 v10 )


# For each year, concatenate individual variables and spatially subset to project
foreach variable ($var)

	set year = 1982
	while ( $year <= 2009 )    #because 2010 is screwed up 
		ncrcat -O -h -v $variable -d lat,$latmin,$latmax -d lon,$lonmin,$lonmax \
						$indir/daily/cfsr_global_{$year}*_daily.nc  \
						$indir/{$project}/{$project}_{$variable}_{$year}.nc ;
		wait
		@ year++
	end 

	@ year--
	set varfiledaily = "cfsr_"{$project}"_"{$variable}"_1982-"{$year}".nc"
	echo 'Concatenated. Now writing file : '$varfiledaily
	ncrcat -O -h {$indir}/{$project}/{$project}_{$variable}_*.nc {$indir}/$project/$varfiledaily;
	wait
	rm  {$indir}/{$project}/{$project}_{$variable}_*.nc 


# Regrid to target resolution -- often CFS 1-degree forecast
	setenv regrid_indir   $indir/{$project}
	setenv regrid_infile  $varfiledaily
	ncl -n -Q cfsr-pagasa_regrid_daily.ncl
	wait

	echo 'done with variable '$variable
end

foreach variable ($var)
	if ($variable == "tas") then
		cp $indir/{$project}/cfsr_{$project}_tas_*cfs-grid.nc  $indir/{$project}/cfsr_{$project}_1982-{$year}_cfs-grid_daily.nc
	else
		ncks -3 -A -h $indir/{$project}/cfsr_{$project}_{$variable}_1982-{$year}_cfs-grid.nc $indir/{$project}/cfsr_{$project}_1982-{$year}_cfs-grid_daily.nc
	endif
end;
wait
rm $indir/$project/cfsr_{$project}*_cfs-grid.nc $indir/$project/cfsr_{$project}_*{$year}.nc


echo '### Completed Daily File for CFSR - '{$project}' - 1982-'{$year}' ###'



