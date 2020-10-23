#!/usr/bin/bash

#grib-module load might be necessary on some servers:
#module load grib-bins
module load netcdf-c
module load netcdf-fortran

#set the root directory of the data collections
basedir=/gpfs/data/
#basedir=/gpfs/home/ncar/test/		#for testing

out_dir=${basedir}/WRFdriver/cfs
mkdir -p ${out_dir}

#Location of operational forecasts:
site=https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs

#PAGASA / Philippines Domain : 
LatMin=-5.
LatMax=25.
LonMin=95.
LonMax=140.

RunOverride="False"

today=`date +%Y%m%d`
#today="20200531"

Year=`date +%Y --date "${today}"`
#Year=2020 #2019		#if override needed
mkdir -p ${out_dir}/${Year}

#Months=`date +%m --date "${today}"`
Months=( 09 )			#if override needed

echo 'Months to look at : '$Months

for M in ${!Months[@]}; do # the "!" forces to loop over the index of the months (0,1,2) instead of the index (01 02, et) 
	Month=$Months #$( printf '%02d' $Months[$M] )
	mkdir -p ${out_dir}/${Year}/${Year}${Month}

	#for each day of the month, 4 long runs are made
	DaysInMonth=$(cal ${Months[$M]} $Year | awk 'NF {DAYS = $NF}; END {print DAYS}')
#	for ((D = 24; D <= 26; ++D)); do
	for ((D = 30; D <= ${DaysInMonth}; ++D)); do

#echo $DaysInMonth		## retain this potential diagnostic as some linux distribution can run into odd behavior
#DaysInMonth=30

		Day=$( printf '%02d' $D )
		YYYYMM=${Year}${Month} 
		YYYYMMDD=${Year}${Month}${Day}
		DayPath=${out_dir}/${Year}/$YYYYMM/$YYYYMMDD
		mkdir -p ${DayPath}

		for Run in 00 06 12 18; do

			nextday=$YYYYMMDD

			fname=${DayPath}/cfsv2_pagasa_${YYYYMMDD}_${Run}z.nc
			if test -f "${fname}"  && [ $RunOverride == "False" ]; then
				echo '*********************************************************'
				echo 'cfs_'${YYYYMMDD}${Run}'Zi : already processed, go to next'
				echo '*********************************************************'
				echo '*********************************************************'
				echo ' '
			else
				echo 'Now processing : cfsv2_pagasa_'${YYYYMMDD}'_'${Run}'z'

				for var in 'pressfc' 'tmp2m' 'tmin' 'tmax' 'q2m' 'prate' 'wnd10m' 'dswsfc' 'dlwsfc' 'uswsfc' 'ulwsfc' 'tmpsfc' ; do

					outfile=${var}.01.${YYYYMMDD}${Run}.daily.grb2
					filenc="$(echo ${outfile} | sed 's/.grb2/.nc/g')"

					wget --directory-prefix=$DayPath --no-parent -nc -e robots=off -r -c -nH -nd -np -A ${outfile} \
							 ${site}/cfs.${YYYYMMDD}/${Run}/time_grib_01 


					/gpfs/home/ncar/wgrib2/wgrib2 ${DayPath}/$outfile   \
							-match ":(SUNSD:surface|PRES:surface|TMP:surface|TMP:2 m above ground|TMIN:2 m above ground|TMAX:2 m above ground|SPFH:2 m above ground|PRATE:surface|UGRD:10 m above ground|VGRD:10 m above ground|DSWRF:surface|DLWRF:surface|USWRF:surface|ULWRF:surface|RH:2 m above ground):"\
							-netcdf ${DayPath}/tmp.nc -inv /dev/null

					ncea -O -d latitude,${LatMin},${LatMax} -d longitude,${LonMin},${LonMax} ${DayPath}/tmp.nc ${DayPath}/${filenc};
					wait
					
					rm ${DayPath}/tmp.nc
				done;
				wait

				cp ${DayPath}/pressfc.01.${YYYYMMDD}${Run}.daily.nc  ${DayPath}/cfsv2_pagasa_${YYYYMMDD}_${Run}z.nc
				rm ${DayPath}/pressfc.01.${YYYYMMDD}${Run}.daily.grb2 ${DayPath}/pressfc.01.${YYYYMMDD}${Run}.daily.nc
				for var in 'tmp2m' 'tmin' 'tmax' 'q2m' 'prate' 'wnd10m' 'dswsfc' 'dlwsfc' 'uswsfc' 'ulwsfc' 'tmpsfc' ; do
					ncks -h -A ${DayPath}/${var}.01.${YYYYMMDD}${Run}.daily.nc ${DayPath}/cfsv2_pagasa_${YYYYMMDD}_${Run}z.nc;
					rm ${DayPath}/${var}*daily.grb2  ${DayPath}/tmp_${var}.nc  ${DayPath}/${var}.01.${YYYYMMDD}${Run}.daily.nc
				done;

			fi
## 
## Following code is faster because of on-server-subsetting. But ...: only 6 months worth of data available!

#				for ((day=0; day<=320; ++day)); do 
#					for hour in 00 06 12 18; do
#						fname=cfs.${YYYYMMDD}${Run}.daily.${nextday}${hour}
#						URL="https://nomads.ncep.noaa.gov/cgi-bin/filter_cfs_flx.pl?file=flxf"${nextday}${hour}".01."${YYYYMMDD}${Run}".grb2&lev_10_m_above_ground=on&lev_2_m_above_ground=on&lev_surface=on&var_DLWRF=on&var_DSWRF=on&var_PRATE=on&var_PRES=on&var_SPFH=on&var_TMAX=on&var_TMIN=on&var_TMP=on&var_UGRD=on&var_ULWRF=on&var_USWRF=on&var_VGRD=on&subregion=&leftlon="${LonMin}"&rightlon="${LonMax}"&toplat="${LatMax}"&bottomlat="${LatMin}"&dir=%2Fcfs."${YYYYMMDD}"%2F"${Run}"%2F6hrly_grib_01"
#						curl ${URL} -o ${DayPath}/${fname}.grib2
#						/gpfs/home/ncar/wgrib2/wgrib2 ${DayPath}/${fname}.grib2 -netcdf ${DayPath}/${fname}.nc -inv /dev/null;
#						wait
#						rm ${DayPath}/${fname}.grib2
#					done
#					nextday=`date -d "$nextday + 1 days" +%Y%m%d`
#				done
#				ncrcat -h -O ${DayPath}/cfs.${YYYYMMDD}${Run}.daily.* ${DayPath}/cfsv2_pagasa_${YYYYMMDD}_${Run}z.nc;
#				wait
#				rm ${DayPath}/*.daily.*
#			fi
	
		done	# next Run
	done		# next Day
done			# next Month 



