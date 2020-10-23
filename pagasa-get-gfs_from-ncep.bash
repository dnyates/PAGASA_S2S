#!/usr/bin/bash
#out_dir="./"

#module load grib-bins
module load netcdf-c
module load netcdf-fortran

#set the root directory of the data collections
basedir=/gpfs/data/
#basedir=/gpfs/home/ncar/test/		#for testing

out_dir=${basedir}/WRFdriver/gfs
mkdir -p ${out_dir}

#site=https://www.ncei.noaa.gov/data/climate-forecast-system-reforecast/access/6-hourly-by-flux-9-month-runs/
#site=https://nomads.ncdc.noaa.gov/data/gfs4 # https://nomads.ncdc.noaa.gov/data/gfs4/201905/20190501/
site=https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod

#BR-West ET-Project
project="pagasa"
LatMin=-5.
LatMax=25.
LonMin=95.
LonMax=140.

RunOverride="False"

today=`date +%Y%m%d`
#today="20200531"
#grab_date=`date +%Y%m%d --date "${today} $1 day"`

Months=`date +%m --date "${today}"`
Months=( 09 )

Year=`date +%Y --date "${today}"`
#Year=2020 #2019
mkdir -p ${out_dir}/${Year}


for M in ${!Months[@]}; do # the "!" forces to loop over the index of the months (0,1,2) instead of the index (01 02, et) ,needed since indexing begins at 0
	Month=$Months #$( printf '%02d' $Months[$M] )
	mkdir -p ${out_dir}/${Year}/${Year}${Month}

	#for each day of the month, 4 long runs are made
	DaysInMonth=$(cal ${Months[$M]} $Year | awk 'NF {DAYS = $NF}; END {print DAYS}') #(30) #cfsr archives in 5 day increments

	for ((D = 27; D <= ${DaysInMonth}; ++D)); do
#	for ((D = 23; D <= 26; ++D)); do

		Day=$( printf '%02d' $D )
		YYYYMM=${Year}${Month}  #{Months[$M]}
		YYYYMMDD=${Year}${Month}${Day} #{Months[$M]}${Day}
		DayPath=${out_dir}/${Year}/$YYYYMM/$YYYYMMDD
		mkdir -p ${DayPath}
		
		
		for Run in 00 06 12 18; do

			fname=${DayPath}/gfs4_pagasa_${YYYYMMDD}_${Run}z.nc
			if test -f "${fname}"  && [ $RunOverride == "False" ]; then
				echo '***********************************'
				echo ${YYYYMMDD}-${Run}': already processed, go to next'
				echo '***********************************'
				echo '***********************************'
				echo ' '
			else
				echo 'Now processing : '${YYYYMMDD}'-'${Run}'z'
				for ((h=1; h<=384; ++h)); do
					hour=$(printf '%03d' $h)
					hourfile='gfs.t'${Run}'z.f'${hour}	

					URL="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl?file=gfs.t"${Run}"z.pgrb2.0p25.f"${hour}"&lev_10_m_above_ground=on&lev_2_m_above_ground=on&lev_surface=on&var_DLWRF=on&var_DSWRF=on&var_PRATE=on&var_PRES=on&var_SPFH=on&var_TMAX=on&var_TMIN=on&var_TMP=on&var_UGRD=on&var_ULWRF=on&var_USWRF=on&var_VGRD=on&subregion=&leftlon="${LonMin}"&rightlon="${LonMax}"&toplat="${LatMax}"&bottomlat="${LatMin}"&dir=%2Fgfs."${YYYYMMDD}"%2F"${Run}
#					echo 'url = '${URL}
					curl ${URL} -o ${DayPath}/${hourfile}.grib2;
					wait

					/gpfs/home/ncar/wgrib2/wgrib2 ${DayPath}/${hourfile}.grib2 -netcdf ${DayPath}/${hourfile}.nc -inv /dev/null;
					rm ${DayPath}/${hourfile}.grib2
					
				done
				
				ncrcat -O -h ${DayPath}/gfs.t${Run}z.f*.nc ${DayPath}/gfs4_pagasa_${YYYYMMDD}_${Run}z.nc;
				wait

				rm ${DayPath}/*.grib2  ${DayPath}/gfs.*.nc
			fi
			         
		done # next Run
	done # next Day
done # next Month 



