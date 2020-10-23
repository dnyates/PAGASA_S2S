load "/gpfs/home/ncar/ncl/ncl_LoadRoutines.ncl"  
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"

function remove_atts(var)
begin
	delete(var@NCL_tag)
	var@time = 1
	delete(var@time)
	return(var)
end

function next_day(ymd)
local nymd,day,month,year,TIME,daysInMonth
begin

	TIME 	= str_split_by_length(ymd,(/4,2,2/))
	year 	= toint(TIME(0))
	month 	= toint(TIME(1))
	day		= toint(TIME(2))

	daysInMonth = days_in_month(year,month)

	if (day.lt.daysInMonth) then
			day = day + 1
	else if (month.lt.12) then
			month 	= month + 1
			day 	= 1 
		 else
			year 	= year + 1
			month 	= 1
			day 	= 1
		 end if
	end if

	nymd = 	tostring_with_format(year,"%4.4d")+ \
			tostring_with_format(month,"%2.2d")+ \
			tostring_with_format(day,"%2.2d")
	nymd@year 	= year
	nymd@month 	= month
	nymd@day 	= day
	return(nymd)
end


;**********************************************************************
; Main Code
;**********************************************************************
begin


;	basedir			= "/gpfs/home/ncar/test/"		;for testing
  	basedir			= "/gpfs/data/"
	indir			= basedir+"WRFdriver/cfs/"

	printDiag		= "False"
	FCSTtype		= "cfs"
	project         = "pagasa"
	readRAD			= True
	forceOverwrite  = False

	TimeZoneShift 	= 8 	; for Philippines

print("here")
; check if month or day provided
	if (.not.isdefined("FCSTinit")) then
		FCSTinit = systemfunc("date +%Y%m")
		print("FCSTinit determined : "+FCSTinit)
	end if
            
	if (strlen(FCSTinit).eq.6) then
		print("Checking all days and ensembles within this month: "+FCSTinit)
		CFSprocess	= "monthly"
	elseif (strlen(FCSTinit).eq.8) then
		print("Checking all ensembles within this day: "+FCSTinit)
		CFSprocess	= "daily"
	else 
		print("Can't check for data as unclear where to look ("+FCSTinit+")")
	end if

	
; collect a list of days
	if (CFSprocess.eq."monthly") then

		FCSTdate	= str_split_by_length(FCSTinit,(/4,2/))
		FCSTyear	= FCSTdate(0)
		FCSTmonth	= FCSTdate(1)
		FCSTyyyymm	= FCSTyear+FCSTmonth

		mdir		= indir+FCSTyear+"/"+FCSTyyyymm+"/"
		dailydir 	= systemfunc("ls --indicator=none --color=never "+mdir)
		if(all(ismissing(dailydir))) then
			print("******* No Forecasts found for this Month : "+FCSTyear+"/"+FCSTmonth+" *********")
			exit
		else
			dailydir := mdir+dailydir
		end if

	else

		FCSTdate	= str_split_by_length(FCSTinit,(/4,2,2/))
		FCSTyear	= FCSTdate(0)
		FCSTmonth	= FCSTdate(1)
		FCSTday		= FCSTdate(2)
 		FCSTyyyymm	= FCSTyear+FCSTmonth
		FCSTymd		= FCSTyear+FCSTmonth+FCSTday

		dailydir	= indir+FCSTyear+"/"+FCSTyyyymm+"/"+FCSTinit

	end if

	ndays = dimsizes(dailydir)


; loop over all available days

	do CFSdays=0,ndays-1

		outdir		= dailydir(CFSdays)+"/"



; collect ensemble list for 
		ensfiles := systemfunc("ls -f "+outdir+"cfsv2*z.nc")
		if(all(ismissing(ensfiles))) then
			print("******* No Forecasts found for this Day : "+dailydir(CFSdays)+" *********")
			continue
		else 
			ncycles := dimsizes(ensfiles)
			print("Ensemble files found: "+ensfiles)
		end if


		basepathposition = str_fields_count(indir,"/") 		; place pointer to name of daily cfs file
		dayfilesposition = basepathposition + 4

		do loop=0,dimsizes(ensfiles)-1

			fpart	= str_get_field(ensfiles(loop),dayfilesposition,"/")
			
        	nametest := str_get_field(fpart,2,"_")
            if (nametest.eq.project) then                    ; check for old raw files that don't contain project code yet
                  
            	if (CFSprocess.eq."monthly") then
                	zdate := str_get_field(fpart,3,"_")
                    ydate := str_split_by_length(zdate,(/4,2,2/))
                    FCSTday 	:= ydate(2) ;tostring_with_format(ydate(2),"%2.2d")
                    FCSTymd 	 = FCSTyear+FCSTmonth+FCSTday
                end if
                zhour	= str_get_field(fpart,4,"_")

            else

            	if (CFSprocess.eq."monthly") then
                	zdate := str_get_field(fpart,2,"_")
                    ydate := str_split_by_length(zdate,(/4,2,2/))
                    FCSTday 	:= ydate(2) ;tostring_with_format(ydate(2),"%2.2d")
                    FCSTymd 	 = FCSTyear+FCSTmonth+FCSTday
                end if
                zhour	= str_get_field(fpart,3,"_")

            end if
                
			hour		= systemfunc("echo "+zhour+" | sed s/z.nc//g")
            dailyfile  	:= 	systemfunc("ls "+dailydir(CFSdays)+"/cfsv2_"+project+"_"+FCSTymd+hour+"Zi_daily.nc")

			if (isfilepresent(dailyfile)) then
				if (forceOverwrite) then
					print("FCST-cycle already processed: "+dailyfile+". Re-processing ...")
				else
					print("FCST-cycle already procesed : "+dailyfile+". Proceeding to next ...")
					continue
				end if
			end if


			print("*** Processing Forecast : "+FCSTymd+"-"+hour+"z")
	        ftmp := addfile(ensfiles(loop),"r")

			tasK					= ftmp->TMP_2maboveground
			lat						= ftmp->latitude
            lat@grid_type			= "Gaussian Latitude/Longitude"
	   		lon						= ftmp->longitude
            lon@grid_type			= "Gaussian Latitude/Longitude"
			tasK!1					= "lat"
			tasK!2					= "lon"
			tasK&lat				= lat
			tasK&lon				= lon
			tasC					= tasK
			tasC					= tasK - 273.15
			tasC@units 				= "C"
			tasC@long_name 			= "Daily Mean Surface Air Temperature (2m)"

			timeunit				= "hours since "+FCSTyear+"-"+FCSTmonth+"-01 00:00:00"
			time 					= cd_convert(tasK&time,timeunit) ;"hours since 2020-04-01 00:00:00")
			time 					= time+TimeZoneShift
			time@long_name 			= "valid time"
			time@_FillValue 		= -999.
			delete_VarAtts(time,"_FillValue")
			tasK&time 				= time
			tasC&time 				= time

;print("Initially available times ")
;print(cd_string(time(0:10),"%Y-%N-%D:%H"))

;               print("Reading Temperatures ...")                        
			tasK_daily				= calculate_daily_values(tasK,"avg",0,False)
			tasC_daily				= calculate_daily_values(tasC,"avg",0,False)
			tasC_daily@_FillValue 	= 1.e20
			tasC_daily				= remove_atts(tasC_daily)
			tasmin					= ftmp->TMIN_2maboveground
			copy_VarCoords(tasC,tasmin)
			tasminK_daily			= calculate_daily_values(tasmin,"min",0,False)
			tasminC_daily   		= tasminK_daily
			tasminC_daily			= tasminK_daily - 273.15
			tasminC_daily@units 	= "C"
			tasminC_daily@long_name = "Daily Minimum Surface Air Temperature (2m)"
			tasminC_daily@_FillValue = 1.e20
			tasminC_daily			= remove_atts(tasminC_daily)

			tasmax					= ftmp->TMAX_2maboveground
			copy_VarCoords(tasC,tasmax)
			tasmaxK_daily			= calculate_daily_values(tasmax,"max",0,False)
			tasmaxC_daily			= tasmaxK_daily
			tasmaxC_daily			= tasmaxK_daily - 273.15
			tasmaxC_daily@units 	= "C"
			tasmaxC_daily@long_name	= "Daily Maximum Surface Air Temperature (2m)"
			tasmaxC_daily@_FillValue = 1.e20
			tasmaxC_daily			= remove_atts(tasmaxC_daily)
	
;		print("Reading Humidity ...")
			q2						= ftmp->SPFH_2maboveground
			copy_VarCoords(tasC,q2)
			q2_daily				= calculate_daily_values(q2,"avg",0,False)
			ps						= ftmp->PRES_surface
			copy_VarCoords(tasC,ps)
			ps_daily				= calculate_daily_values(ps,"avg",0,False)
			ps_daily@long_name 		= "surface pressure"
			ps_daily@units  		= "Pa"
			ps_daily@_FillValue 	= 1.e20
			ps_daily				= remove_atts(ps_daily)

			rhum_daily				= q2_daily
			rhum_daily				= relhum(tasK_daily,q2_daily,ps_daily)
			rhum_daily@long_name  	= "relative humidity at surface"
			rhum_daily@short_name 	= "rel hum"
			rhum_daily@units 		= "percent"
			rhum_daily!0			= "time"
			rhum_daily!1			= "lat"
			rhum_daily!2			= "lon"
			rhum_daily&lat			= lat
			rhum_daily&lon			= lon
			rhum_daily@_FillValue 	= 1.e20
			rhum_daily				= remove_atts(rhum_daily)

			
;		print("Reading Wind ...")
			u10						= ftmp->UGRD_10maboveground
			copy_VarCoords(tasC,u10)
			v10						= ftmp->VGRD_10maboveground
			copy_VarCoords(tasC,v10)
			windspeed				= wind_speed(u10,v10)
			windspeed_daily 		= calculate_daily_values(windspeed,"avg",0,False)
			windspeed_daily@units 	= "m/s"
			windspeed_daily@level 	= "10m"
			windspeed_daily@_FillValue = 1.e20
			windspeed_daily			= remove_atts(windspeed_daily)

			u10_daily				= calculate_daily_values(u10,"avg",0,False)
			u10_daily@units	        = "m/s"
			u10_daily@long_name     = "zonal component of surface wind"
			u10_daily@standard_name	= "eastward_component"
			u10_daily@level	        = "10m"
			u10_daily@_FillValue    = 1.e20
			u10_daily@standard_name = "eastward_component"
			v10_daily				= calculate_daily_values(u10,"avg",0,False)
			v10_daily@units	        = "m/s"
			v10_daily@long_name     = "meridional component of surface wind"
			v10_daily@standard_name	= "northward_component"
			v10_daily@level	        = "10m"
			v10_daily@_FillValue    = 1.e20
			v10_daily@standard_name = "northward_component"
			u10_daily				= remove_atts(u10_daily)
			v10_daily				= remove_atts(v10_daily)


;		print("Reading Precipitation ...")
			pr						= ftmp->PRATE_surface
			copy_VarCoords(tasC,pr)
			pr_daily				= calculate_daily_values(pr,"avg",0,False)
			pr_daily				= pr_daily * 86400.
			pr_daily@units			= "mm/day"
			pr_daily@long_name 		= "precipitation"
			pr_daily@_FillValue 	= 1.e20
			pr_daily				= remove_atts(pr_daily)



;		print("Now compute ET ...")
; **********************************************
; Penman-Monthip constants:  refevt_penman_fao56
			krs	    = 0.16
			albedo	= 0.23
			cnum	= 900.0
			cden	= 0.34
			G      	= 0.0         
        
			g  		= psychro_fao56(ps_daily, (/1,2/))					; (Pa,kPa)

            slp     := (4098. * (0.6108 * exp((17.27 * tasC_daily) / (tasC_daily+237.3)))) / ((tasC_daily+237.3)*(tasC_daily+237.3))
			esAvg   := 0.6108 * exp((17.27 * tasC_daily)/(tasC_daily + 237.3))
			etmin	:= 0.6108 * exp((17.27 * tasminC_daily)/(tasminC_daily + 237.3))
			etmax	:= 0.6108 * exp((17.27 * tasmaxC_daily)/(tasmaxC_daily + 237.3))
			ea	:= rhum_daily / 100. * ((etmin + etmax) / 2.)

			edef 	:= esAvg-ea           
			edef 	:= where(edef.le.0.,0.,edef)

			wind	= u2_fao56(windspeed_daily,10,(/0,0/))   ; unit: 0=m/s, 1=km/hr, 2=mph

		; compute Julian Day of Year
			time_daily = tasK_daily&time
			delete(time_daily@_FillValue)
			TIME	= cd_calendar(time, 0)           ; convert to yyyy,mm,dd
			year	= toint( TIME(:,0) )           	 ; clarity; explicitly extract/assign to variables
			month	= toint( TIME(:,1) )	
			day		= toint( TIME(:,2) )
			jday	= day_of_year(year,month,day)
	

		; estimate radiation fields
            
 
			if (isdefined("readRAD")) then
;				print("Read radiation fields from model ...")
				rsds		= ftmp->DSWRF_surface
				copy_VarCoords(tasC,rsds)
				rsds_daily	= calculate_daily_values(rsds,"avg",0,False)

				rsus		= ftmp->USWRF_surface
				copy_VarCoords(tasC,rsus)
				rsus_daily	= calculate_daily_values(rsus,"avg",0,False)
	
				rlds		= ftmp->DLWRF_surface
				copy_VarCoords(tasC,rlds)
				rlds_daily	= calculate_daily_values(rlds,"avg",0,False)

				rlus		= ftmp->ULWRF_surface
				copy_VarCoords(tasC,rlus)
				rlus_daily	= calculate_daily_values(rlus,"avg",0,False)
			
				nswrad 		= rlus_daily
				nswrad 		= (rsds_daily - rsus_daily) * 86400. / 1.e6
				nswrad@units = "MJ/(m2-day)"
				nlwrad 		= rlus_daily
				nlwrad 		= (rlus_daily - rlds_daily) * 86400. / 1.e6
				nlwrad@units = "MJ/(m2-day)"

				netrad 		= netrad_fao56(nswrad,nlwrad)
				netrad@units = "MJ/(m2-day)"
				netrad@_FillValue = 1.e20
				netrad		= where(netrad.le.0.,0.1,netrad)
		
				delete([/ rsds,rsds_daily,rsus,rsus_daily,rlds,rlds_daily,rlus,rlus_daily /])

			else

				print("Estmiate radiation fields in this calculation ...")
				radext 		= radext_fao56(jday, lat, 1)   ; output in MJ/(m2*day)
				radext_field = tasminK_daily
				do j=0,dimsizes(lon)-1
					radext_field(:,:,j) = (/ radext /)
				end do
				radsol 		= radsol3_hargreaves_fao56(tasminK_daily, tasmaxK_daily, radext_field, krs, (/1,1,1/))  ; 22.29 MJ/(m2-day)
                        
				nlwrad		= netlw_fao56(tasminK_daily, tasmaxK_daily, ea, radext_field, radsol, (/1,2,1,1/),False)
				nswrad		= netsw_fao56(radsol,albedo)

				netrad  	= netrad_fao56(nswrad,nlwrad) ;units: MJ/(m2-day)
				netrad@_FillValue = 1.e20

				delete([/ radext,radext_field,radsol /])

			end if


			output_u = 0 ; units: 0=mm/day, 1=MJ/(m2-day), 2= W/m2

			refevt = refevt_penman_fao56(tasC_daily, netrad, G, g, wind, edef, slp, albedo, cnum, cden, output_u)   ; units: 0=mm/day, 1=MJ/(m2-day), 2=W/m2
	        copy_VarCoords(tasminK_daily,refevt)
	        refevt@_FillValue = 0.
	        refevt = where(refevt.eq.refevt@_FillValue,0.,refevt)

; cut back time line
; trim all variables and set proper dimensions, incl. reasigning time
;print("Now Daily times for init-hour : "+hour)
;ds=dimsizes(tasC_daily&time)
;print("ds : "+ds)
;print("start : "+cd_string(tasC_daily&time(0:3),"%Y-%N-%D"))
;print("        "+cd_string(tasC&time(0:30),"%Y-%N-%D:%H"))
;print("end   : "+cd_string(tasC_daily&time(ds-4:ds-1),"%Y-%N-%D"))
			if (hour.eq."12") then 		; all other init-hours only generate partial first day
				firstday	= 0
			else
				firstday 	= 1
			end if
			dimtime 		= dimsizes(tasC_daily&time)
			lastday 		= dimtime-2

			refevt 			:= refevt(firstday:lastday,:,:)
			tasC_daily 		:= tasC_daily(firstday:lastday,:,:)
			tasminC_daily 	:= tasminC_daily(firstday:lastday,:,:)
			tasmaxC_daily 	:= tasmaxC_daily(firstday:lastday,:,:)
			rhum_daily		:= rhum_daily(firstday:lastday,:,:)
			windspeed_daily := windspeed_daily(firstday:lastday,:,:)
			u10_daily		:= u10_daily(firstday:lastday,:,:)
			v10_daily		:= v10_daily(firstday:lastday,:,:)
			ps_daily		:= ps_daily(firstday:lastday,:,:)
			ps_daily		 = ps_daily * 0.01
			ps_daily@units 	 = "hPa"
			netrad			:= netrad(firstday:lastday,:,:)
			pr_daily		:= pr_daily(firstday:lastday,:,:)

			;reset "hour" in time stamp to 00
			time := tasC_daily&time - 2
			time@timezone = "Philippines Time"
            refevt&time = time
            tasC_daily&time = time
            tasminC_daily&time = time
            tasmaxC_daily&time = time
            rhum_daily&time = time
            windspeed_daily&time = time
            u10_daily&time = time
            v10_daily&time = time
            ps_daily&time = time
            netrad&time = time
            pr_daily&time = time
                       
			print("writing CFS hindcast of "+FCSTymd+"-"+hour+" daily time series to netcdf file ...")
			ncoutfile = "cfsv2_"+project+"_"+FCSTymd+hour+"Zi_daily" ;outfile
			global_attributes_of_source_dataset = transfer_global_attributes(ftmp)
			collection = [/ refevt, tasC_daily, tasminC_daily, tasmaxC_daily, rhum_daily, windspeed_daily, \
							u10_daily, v10_daily, ps_daily, netrad, pr_daily, global_attributes_of_source_dataset/]
			collection_varnames = (/"refevt", "tas", "tasmin", "tasmax", "rhum", "windspeed", \
									"u10","v10","ps","netrad","pr","global_attributes_of_source_dataset"/)
			write_list_to_netcdf_standalone(collection,collection_varnames,outdir,ncoutfile) 
			delete([/ncoutfile,collection,collection_varnames/])

			delete([/refevt, tasK,tasK_daily, tasC,tasC_daily, tasminK_daily,tasmaxK_daily, tasminC_daily,tasmaxC_daily,\
				 tasmin,tasmax,esAvg,ea,edef,nlwrad,nswrad,netrad, pr,pr_daily, q2,q2_daily, ps,ps_daily, \
				 u10,u10_daily, v10,v10_daily, windspeed,windspeed_daily,wind, rhum_daily, g,slp/])

			delete([/time,time_daily,TIME,year,month,day,jday,ftmp/])

		end do	; end loop over ensemble

	end do  ; end loop over days

end
