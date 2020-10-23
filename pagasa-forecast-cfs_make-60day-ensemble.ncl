load "/gpfs/home/ncar/ncl/ncl_LoadRoutines.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"

  

function day_before(year,month,day)
local y,m,d
begin
	if (day.eq.1) then
		if (month.eq.1) then
			y = year -1
			m = 12
			d = 31
		else
			y = year
			m = month - 1
			d = days_in_month(y,m)
		end if
	else
		y = year
		m = month
		d = day - 1
	end if

	YY 	= tostring(y)
	YM 	= YY+tostring_with_format(m,"%2.2d")
	YMD = YM+tostring_with_format(d,"%2.2d")

	return(YMD)
end

function next_day(ymd)
local nymd,day,month,year,TIME,daysInMonth
begin

	TIME = str_split_by_length(ymd,(/4,2,2/))
	year = toint(TIME(0))
	month = toint(TIME(1))
	day= toint(TIME(2))

	daysInMonth = days_in_month(year,month)

	if (day.lt.daysInMonth) then
		day = day + 1
	else if (month.lt.12) then
		month = month + 1
		day = 1
	else
		year = year + 1
		month = 1
		day = 1
	end if
	end if

	nymd = tostring_with_format(year,"%4.4d")+ \
		   tostring_with_format(month,"%2.2d")+ \
           tostring_with_format(day,"%2.2d")
	nymd@year = year
	nymd@month = month
	nymd@day = day

	return(nymd)
end



begin

	indir		= getenv("indir")
;    indir		= "/gpfs/data/WRFdriver/cfs/"
	varlist 	= (/ "tas", "tasmin", "tasmax", "refevt", "pr", "ps", "rhum", "windspeed", "u10", "v10", "netrad" /)
	project		= getenv("project")

	stat 		= (/ 2, 3, 6, 8, 10, 13, 14 /)
	stat!0		= "stat"
	stat&stat	= stat
	stat@units	= "min 10th 25th 50th 75th 90th max"

	cfsyear		= getenv("cfsyear")  
	cfsmonth	= getenv("cfsmonth") 
	cfsday		= getenv("cfsday")   
	year		= stringtointeger(cfsyear)
	month		= stringtointeger(cfsmonth)
	day			= stringtointeger(cfsday)
	YYYYMMDD	= cfsyear+cfsmonth+cfsday
	YYYYMM		= cfsyear+cfsmonth

	outdir		= indir+tostring(year)+"/"+YYYYMM+"/"+YYYYMMDD+"/"

	nextday 	= next_day(YYYYMMDD)
	nextday 	= next_day(nextday)
	time 		= ispan(0,59,1)
	time!0		= "time"
	time&time 	= time
	time@units 	= "days since "+nextday@year+"-"+nextday@month+"-"+nextday@day+" 00:00:00"

	strday 		= cd_string(time(0),"%Y%N%D")	
	endday		= cd_string(time(59),"%Y%N%D")

print("Forecast Period : "+strday+" - "+endday)

;	read names of last 16 forecasts
	filelist 		= new(16,"string")
	currentday		:= YYYYMMDD
	do l=0,3
		lastday		:= str_split_by_length(currentday,(/4,2,2/))
		YY			:= lastday(0)
		YM			:= YY+lastday(1)
		YMD			:= YM+lastday(2)
		dummy 		:= systemfunc("ls "+indir+YY+"/"+YM+"/"+YMD+"/*_daily.nc")		 	
		do i=0,dimsizes(dummy)-1
			filelist(l*4+i) = dummy(i)	 	
		end do
		year		:= tointeger(lastday(0))
		month		:= tointeger(lastday(1))
		day			:= tointeger(lastday(2))
		currentday	:= day_before(year,month,day)
	end do

;	print("File list to process : "+filelist)
 	; only advance if 16 ore more forecasts are available
	nn = (num(ismissing(filelist)))
	if(any(ismissing(filelist))) then
		print("***************************************************************")
		print(" Total number of required ensemble members over past 4 days: 16")
		print(" At this part of the month, there are "+nn+" forecasts members missing")
		print(" Ending ensemble calculation")
		print("***********************************************************")
		exit
	else
		print("***************************************************************")
		print(" Total number of expected ensemble members over past 4 days: 16")
		print(" At this part of the month, there are "+(16-nn)+" forecasts members available")
		print("***********************************************************")
	end if

	do varloop=0,dimsizes(varlist)-1

 		first = True
        do floop=0,15
	
			if (.not.isfilepresent(filelist(floop)))
				continue

			else
				infile 		:= addfile(filelist(floop),"r")
				var 		:= infile->$varlist(varloop)$
				if (any(isnan_ieee(var))) then
					value 		:= var@_FillValue
					replace_ieeenan (var, value, 0)
				end if
				vtime   	:= infile->time
				if (first.eq.True) then
					lat		= infile->lat
					lon		= infile->lon
                    ensemble = new((/16,dimsizes(time),dimsizes(lat),dimsizes(lon)/),"float",1.e20)
                    first 	= False
				end if

				vtimestr 	:= cd_string(vtime,"%Y%N%D")
				stridx		:= ind(vtimestr.eq.strday)
				endidx		:= ind(vtimestr.eq.endday)				
				ensemble(floop,:,:,:) = var(stridx:endidx,:,:)
			end if

		end do

		varstat := new((/dimsizes(stat),dimsizes(time),dimsizes(lat),dimsizes(lon)/),"float")
		varstat!0 		= "stat"
		varstat!1 		= "time"
		varstat!2 		= "lat"
		varstat!3 		= "lon"
		varstat&stat 	= stat
		varstat&time 	= time
		varstat&lat  	= lat
		varstat&lon	 	= lon
		varstat@_FillValue = 1.e20

		do i=0,dimsizes(time)-1
			do j=0,dimsizes(lat)-1
			do k=0,dimsizes(lon)-1
				if(varlist(varloop).eq."refevt") then
                	nn = num(ismissing(ensemble(:,i,j,k)))
                    if (nn.ne.0) then
                    	print("number of missing values: "+nn+" at time: "+i+" at lat lon: "+j+" "+k)
                        ensemble(:,i,j,k) = where(ismissing(ensemble(:,i,j,k)),0.0001,ensemble(:,i,j,k))
					end if
                end if
                vardummy 	:= stat_dispersion(ensemble(:,i,j,k),False)
				varstat(:,i,j,k) = (/ vardummy(stat) /)
			end do
			end do
		end do
		copy_VarAtts(var,varstat)


		newtime = time(0::10)
		newtime@units = "days since "+nextday@year+"-"+nextday@month+"-"+nextday@day+" 00:00:00"
		newtime@decade = "beginning of the 10-day average"

		;generate 10-day averages
		varstatout = varstat(:,0:5,:,:)
		do dloop=0,5
			if (varlist(varloop).eq."pr") then
				varstatout(:,dloop,:,:) = dim_sum_n_Wrap(varstat(:,dloop*10:dloop*10+9,:,:),1)
				varstatout@units = "mm/decade"
			else
				varstatout(:,dloop,:,:) = dim_avg_n_Wrap(varstat(:,dloop*10:dloop*10+9,:,:),1)
			end if
		end do
		varstatout&time = newtime

		system ("mkdir -p "+outdir)
		if (isfilepresent(outdir+varlist(varloop)+"_"+project+"_"+YYYYMMDD+"i_"+strday+"-"+endday+"_60day-ensemble.nc")) then
			system ("rm "+outdir+varlist(varloop)+"_"+project+"_"+YYYYMMDD+"i_"+strday+"-"+endday+"_60day-ensemble.nc")             ; remove any pre-existing file
		end if
        print("Outfile : "+outdir+varlist(varloop)+"_"+project+"_"+YYYYMMDD+"i_"+strday+"-"+endday+"_60day-ensemble.nc")
        fout := addfile(outdir+varlist(varloop)+"_"+project+"_"+YYYYMMDD+"i_"+strday+"-"+endday+"_60day-ensemble.nc","c")
        
		setfileoption(fout,"DefineMode",True)
		fAtt                = True            ; assign file attributes
		fAtt@title         := "CFS-smoothed 60-day ensemble forecast based on past 4 forecast days"  
		fAtt@creation_date := systemfunc ("date")        
		fileattdef( fout, fAtt )            ; copy file attributes    

		dimNames = (/"stat", "time", "lat", "lon" /)  
		dimSizes = (/ dimsizes(stat), dimsizes(newtime), dimsizes(lat), dimsizes(lon) /) 
		dimUnlim = (/ False, False , False, False/)   
		filedimdef(fout,dimNames,dimSizes,dimUnlim)

		filevardef(fout, "stat" ,typeof(stat),getvardims(stat)) 
		filevardef(fout, "time" ,typeof(newtime),getvardims(newtime)) 
		filevardef(fout, "lat"  ,typeof(lat),getvardims(lat))                          
		filevardef(fout, "lon"  ,typeof(lon),getvardims(lon))                          
		filevardef(fout, varlist(varloop) ,typeof(varstatout)  ,getvardims(varstatout))    

		filevarattdef(fout,varlist(varloop),varstatout)  	; copy T attributes
		filevarattdef(fout,"stat" ,stat)                    ; copy time attributes
		filevarattdef(fout,"time" ,newtime)                 ; copy time attributes
		filevarattdef(fout,"lat"  ,lat)                     ; copy lat attributes
		filevarattdef(fout,"lon"  ,lon)                     ; copy lon attributes

		setfileoption(fout,"DefineMode",False)

		fout->stat   				= (/stat/)     
		fout->time   				= (/newtime/)     
		fout->lat    				= (/lat/)
		fout->lon    				= (/lon/) 
		fout->$varlist(varloop)$	= varstatout

	end do


end

