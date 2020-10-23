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




;**********************************************************************
; Main Code
;**********************************************************************
begin

;	basedir		= "/gpfs/home/ncar/test/"
	basedir		= "/gpfs/data/"	
	indir		= basedir+"WRFdriver/gfs/"

	FCSTtype	= "gfs"
	project		= "pagasa"
	readRAD		= True
	doRegrid	= False ;True
	forceOverwrite  = False ; True ;False

	TimeZoneShift   = 8    ; set for Philippines


; check if month or day provided

	if (.not.isdefined("FCSTinit")) then
		FCSTinit = systemfunc("date +%Y%m")
		print("FCSTinit determined : "+FCSTinit)
	end if  
              
	if (strlen(FCSTinit).eq.6) then
		print("Checking files to process for all Days within this Year-Month: "+FCSTinit)
		GFSprocess	= "monthly"
	elseif (strlen(FCSTinit).eq.8) then
		print("Checking files to process within this Day: "+FCSTinit)
		GFSprocess	= "daily"
	else 
		print("Can't check for data as unclear where to look ("+FCSTinit+")")
	end if

	
; collect a list of days
	if (GFSprocess.eq."monthly") then

		FCSTdate	= str_split_by_length(FCSTinit,(/4,2/))
        FCSTyear	= FCSTdate(0)
        FCSTmonth	= FCSTdate(1)
 		FCSTyyyymm	= FCSTyear+FCSTmonth

		ddir		= indir+FCSTyear+"/"+FCSTyyyymm+"/"
		dailydir 	= systemfunc("ls --indicator=none --color=never "+ddir)
		if (all(ismissing(dailydir))) then
			print("******* No Data found for this year and month : "+FCSTyear+"/"+FCSTyyyymm+" *********")
			exit
		else
			dailydir := ddir+dailydir
		end if

	else

		FCSTdate	= str_split_by_length(FCSTinit,(/4,2,2/))
		FCSTyear	= FCSTdate(0)
		FCSTmonth	= FCSTdate(1)
		FCSTday		= FCSTdate(2)
 		FCSTyyyymm	= FCSTyear+FCSTmonth
		FCSTymd		= FCSTyear+FCSTmonth+FCSTday

		dailydir	= indir+FCSTyear+"/"+FCSTyyyymm+"/"+FCSTymd

	end if

	ndays = dimsizes(dailydir)

	basepathposition = str_fields_count(indir,"/") 		; place pointer to name of daily cfs file
	dayposition = basepathposition + 3

	print("days to process: "+dailydir)
	do GFSday=0,ndays-1

		outdir		= dailydir(GFSday)+"/"

		if (GFSprocess.eq."monthly") then
			FCSTymd		:= str_get_field(dailydir(GFSday),dayposition,"/")
			timeparts 	:= str_split_by_length(FCSTymd,(/4,2,2/))	; reading just the day-month-year dir name
			FCSTday		:= timeparts(2)
		end if 
		gfscycles := systemfunc("ls "+outdir+"gfs4_*z.nc")  ; for new operational data from ncep
		if (all(ismissing(gfscycles))) then
			print("****** No Forecasts found in this Day : "+FCSTyear+"/"+FCSTyyyymm+"/"+FCSTday+" **********")
			continue
		else
			ncycles := dimsizes(gfscycles)
		end if



		basepathposition = str_fields_count(indir,"/") 		; place pointer to name of daily cfs file
		dayfilesposition = basepathposition + 4           
            
		do cycle=0,ncycles-1

			print("***** Next Forecast Cycle : "+gfscycles(cycle))
			fpart= str_get_field(gfscycles(cycle),dayfilesposition,"/")		; on hydro-c1
			zhour= str_get_field(fpart,4,"_")
			hour= systemfunc("echo "+zhour+" | sed s/z.nc//g")

			if (hour.eq."18") then								; 18-hour forecast is actually 2 days out
				newday = next_day(FCSTymd)
				newday = next_day(newday)	
				dailyfile := systemfunc("ls "+indir+newday@year+"/"+\
							tostring_with_format(newday@year,"%4.4d")+tostring_with_format(newday@month,"%2.2d")+"/"+ \
							newday+"/gfs4_"+project+"_"+FCSTymd+hour+"Zi_"+newday+"-*_daily.nc")
			else
				newday = next_day(FCSTymd)
				dailyfile  := systemfunc("ls "+indir+newday@year+"/"+\
							tostring_with_format(newday@year,"%4.4d")+tostring_with_format(newday@month,"%2.2d")+"/"+ \
							newday+"/gfs4_"+project+"_"+FCSTymd+hour+"Zi_"+newday+"-*_daily.nc")
			end if

			if (isfilepresent(dailyfile)) then
				if (forceOverwrite) then
					print("FCST-cycle already processed: "+dailyfile+". Re-processing ...")
				else
					print("FCST-cycle already procesed : "+dailyfile+". Proceeding to next ...")
					continue
				end if
			end if
                



			print("Processing Forecast : "+FCSTymd+"_"+hour+"z")
			ftmp = addfile(gfscycles(cycle),"r")

			tasK					= ftmp->TMP_2maboveground
			lat						:= ftmp->latitude
    		lat@grid_type			= "Gaussian Latitude/Longitude"
   			lon						:= ftmp->longitude
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
			tasK&time 				= time
			tasC&time 				= time

;print("list the full series of time steps prior to daily mean calculation")	
;print(cd_string(tasC&time,"%Y-%N-%D:%H"))
			
			tasK_daily				= calculate_daily_values(tasK,"avg",0,False)
			tasC_daily				= calculate_daily_values(tasC,"avg",0,False)
			tasC_daily@_FillValue 	= 1.e20
			delete_VarAtts(tasC_daily,(/"time","NCL_tag"/))
			tasmin					= ftmp->TMIN_2maboveground
			copy_VarCoords(tasC,tasmin)
			tasminK_daily			= calculate_daily_values(tasmin,"min",0,False)
			tasminC_daily   		= tasminK_daily
			tasminC_daily			= tasminK_daily - 273.15
			tasminC_daily@units 	= "C"
			tasminC_daily@_FillValue = 1.e20
			delete_VarAtts(tasminC_daily,(/"time","NCL_tag"/))
	
			tasmax					= ftmp->TMAX_2maboveground
			copy_VarCoords(tasC,tasmax)
			tasmaxK_daily			= calculate_daily_values(tasmax,"max",0,False)
			tasmaxC_daily			= tasmaxK_daily
			tasmaxC_daily			= tasmaxK_daily - 273.15
			tasmaxC_daily@units 	= "C"
			tasmaxC_daily@long_name	= "Daily Maximum Surface Air Temperature (2m)"
			tasmaxC_daily@_FillValue = 1.e20
			delete_VarAtts(tasmaxC_daily,(/"time","NCL_tag"/))
                
	
;			print("Reading Humidity ...")
			q2 						= ftmp->SPFH_2maboveground
			copy_VarCoords(tasC,q2)
			q2_daily				= calculate_daily_values(q2,"avg",0,False)
			ps						= ftmp->PRES_surface
			copy_VarCoords(tasC,ps)
			ps_daily				= calculate_daily_values(ps,"avg",0,False)
			ps_daily@long_name 		= "surface pressure"
			ps_daily@units			= "Pa"
			ps_daily@_FillValue 	= 1.e20
			delete_VarAtts(ps_daily,(/"time","NCL_tag"/))
                
			rhum					= q2
			rhum_daily				= relhum(tasK_daily,q2_daily,ps_daily)
			rhum_daily@long_name  	= "relative humidity"
			rhum_daily@units		= "percent"
			rhum_daily!0			= "time"
			rhum_daily!1			= "lat"
			rhum_daily!2			= "lon"
			rhum_daily&lat			= lat
			rhum_daily&lon			= lon
			rhum_daily@_FillValue = 1.e20
			delete_VarAtts(rhum_daily,(/"time","NCL_tag"/))
                

;			print("Reading Wind ...")
			u10						= ftmp->UGRD_10maboveground
			copy_VarCoords(tasC,u10)
			v10						= ftmp->VGRD_10maboveground
			copy_VarCoords(tasC,v10)
			windspeed				= wind_speed(u10,v10)
			windspeed_daily 		= calculate_daily_values(windspeed,"avg",0,False)
			windspeed_daily@long_name = "windspeed"
			windspeed_daily@standard_name = "windspeed"                
			windspeed_daily@units 	= "m s-1"
			windspeed_daily@level 	= "10m"
			windspeed_daily@_FillValue = 1.e20
			delete_VarAtts(windspeed_daily,(/"time","NCL_tag"/))
   	             
			u10_daily				= calculate_daily_values(u10,"avg",0,False)
			u10_daily@units 		= "m s-1"
			u10_daily@long_name 	= "u-component"
			u10_daily@standard_name = "eastward_component"
			delete(u10_daily@short_name)
			u10_daily@level 		= "10m"
			u10_daily@_FillValue 	= 1.e20
			delete_VarAtts(u10_daily,(/"time","NCL_tag"/))
   	             
			v10_daily				= calculate_daily_values(u10,"avg",0,False)
			v10_daily@units 		= "m s-1"
			v10_daily@long_name 	= "v-component"
			v10_daily@standard_name = "northward_component"
			v10_daily@level 		= "10m"
			delete(v10_daily@short_name)
			v10_daily@_FillValue 	= 1.e20
			delete_VarAtts(v10_daily,(/"time","NCL_tag"/))
                

;			print("Reading Precipitation ...")
			pr						= ftmp->PRATE_surface
			copy_VarCoords(tasC,pr)
			pr_daily				= calculate_daily_values(pr,"avg",0,False)
			pr_daily				= pr_daily * 86400.
			pr_daily@units			= "mm/day"
			pr_daily@long_name 		= "precipitation"



;		print("Now compute ET ...")
; **********************************************
; Penman-Monthip constants:  refevt_penman_fao56
			krs	    = 0.16
			albedo	= 0.23
			cnum	= 900.0
			cden	= 0.34
			G      	= 0.0         
    	    
			g  	= psychro_fao56(ps_daily, (/1,2/))					; (Pa,kPa)
			slp = (4098. * (0.6108 * exp((17.27 * tasC_daily) / (tasC_daily+237.3)))) / \
						((tasC_daily+237.3)*(tasC_daily+237.3))

			esAvg   := 0.6108 * exp((17.27 * tasC_daily)/(tasC_daily + 237.3))
			etmin	:= 0.6108 * exp((17.27 * tasminC_daily)/(tasminC_daily + 237.3))
			etmax	:= 0.6108 * exp((17.27 * tasmaxC_daily)/(tasmaxC_daily + 237.3))
			ea	:= (rhum_daily / 100.) * ((etmin + etmax) / 2.)
			edef 	:= esAvg-ea           
			edef 	:= where(edef.le.0.,0.,edef)

			wind	= u2_fao56(windspeed_daily,10,(/0,0/))   ; unit: 0=m/s, 1=km/hr, 2=mph

			; compute Julian Day of Year
			time_daily := tasK_daily&time
			delete(time_daily@_FillValue)
			TIME	:= cd_calendar(time_daily, 0)           ; convert to yyyy,mm,dd
			year	:= toint( TIME(:,0) )           	 ; clarity; explicitly extract/assign to variables
			month	:= toint( TIME(:,1) )	
			day	:= toint( TIME(:,2) )
			jday	:= day_of_year(year,month,day)
	

		; estimate radiation fields
            
 
		if (isdefined("readRAD")) then
;	print("Read radiation fields from model ...")
			rsds			= ftmp->DSWRF_surface
			copy_VarCoords(tasC,rsds)
			rsds_daily		= calculate_daily_values(rsds,"avg",0,False)
 
			rsus			= ftmp->USWRF_surface
			copy_VarCoords(tasC,rsus)
			rsus_daily		= calculate_daily_values(rsus,"avg",0,False)
	
			rlds			= ftmp->DLWRF_surface
			copy_VarCoords(tasC,rlds)
			rlds_daily		= calculate_daily_values(rlds,"avg",0,False)

			rlus			= ftmp->ULWRF_surface
			copy_VarCoords(tasC,rlus)
			rlus_daily		= calculate_daily_values(rlus,"avg",0,False)
			
			nswrad 			= rsds_daily
			nswrad 			= (rsds_daily - rsus_daily) * 86400. / 1000000. 		; conversion  W m-2 to MJ / m-2 day
			nswrad@units	= "MJ/(m2-day)"
			nlwrad 			= rlus_daily
			nlwrad 			= (rlus_daily - rlds_daily) * 86400. / 1000000.
			nlwrad@units	= "MJ/(m2-day)"

			netrad 			= netrad_fao56(nswrad,nlwrad)
			netrad@units	= "MJ/(m2-day)"
                        netrad@_FillValue = 1.e20
                        netrad			= where(netrad.lt.0.,0.1,netrad)

                        
			delete([/ rsds,rsds_daily,rsus,rsus_daily,rlds,rlds_daily,rlus,rlus_daily /])

		else

			print("Estmiate radiation fields in this calculation ...")
			radext 	= radext_fao56(jday, lat, 1)   ; output in MJ/(m2*day)
			radext_field = tasminK_daily
			do j=0,dimsizes(lon)-1
				radext_field(:,:,j) = (/ radext /)
			end do
			radsol 		= radsol3_hargreaves_fao56(tasminK_daily, tasmaxK_daily, radext_field, krs, (/1,1,1/))  ; 22.29 MJ/(m2-day)
                        
			nlwrad		= netlw_fao56(tasminK_daily, tasmaxK_daily, ea, radext_field, radsol, (/1,2,1,1/),False)
			nswrad		= netsw_fao56(radsol,albedo)

			netrad  	= netrad_fao56(nswrad,nlwrad) ;units: MJ/(m2-day)

			delete([/ radext,radext_field,radsol /])

		end if


		output_u = 0 ; units: 0=mm/day, 1=MJ/(m2-day), 2= W/m2

		refevt = refevt_penman_fao56(tasC_daily, netrad, G, g, wind, edef, slp, albedo, cnum, cden, output_u)   ; units: 0=mm/day, 1=MJ/(m2-day), 2=W/m2
        copy_VarCoords(tasminK_daily,refevt)
        refevt@_FillValue = 0.
        refevt = where(refevt.eq.refevt@_FillValue,0.,refevt)
                        

; trim all variables and set proper dimensions, incl. reasigning time
		time := tasC_daily&time
		firstday = 1
		lastday  = 15

;print("All time variables available for hour - "+hour)
;ttime = cd_string(time,"%Y-%N-%D")
;print(ttime)

		if (dimsizes(tasC_daily&time).lt.16) then
			print("*******************************************************")
			print(" incomplete forecast : skipping "+FCSTymd+"-"+hour)
			print("*******************************************************")
			print("*******************************************************")
			print(" cleaning up archive by removing incomplete data ")
			print("*******************************************************")
			system("echo removing: "+gfscycles(cycle)+"  ****************")
			system("rm "+gfscycles(cycle))
			print("*******************************************************")
			continue
		end if                 

		tasC_daily&time := time
		tasC_daily 		:= tasC_daily(firstday:lastday,:,:)
		refevt&time  	:= time
		refevt 			:= refevt(firstday:lastday,:,:)
		tasminC_daily&time := time
		tasminC_daily 	:= tasminC_daily(firstday:lastday,:,:)
		tasmaxC_daily&time  := time
		tasmaxC_daily 	:= tasmaxC_daily(firstday:lastday,:,:)
		rhum_daily&time := time
		rhum_daily 		:= rhum_daily(firstday:lastday,:,:)
		windspeed_daily&time  := time
		windspeed_daily := windspeed_daily(firstday:lastday,:,:)
		u10_daily&time  := time
		u10_daily 		:= u10_daily(firstday:lastday,:,:)
		v10_daily&time  := time
		v10_daily 		:= v10_daily(firstday:lastday,:,:)
		ps_daily&time   := time
		ps_daily 		:= ps_daily(firstday:lastday,:,:)
		ps_daily		 = ps_daily * 0.01
		ps_daily@units   = "hPa"
		netrad&time     := time
		netrad 			:= netrad(firstday:lastday,:,:)
		pr_daily&time   := time
		pr_daily 		:= pr_daily(firstday:lastday,:,:)

		;assign correct time
		time			:= tasC_daily&time
		delete_VarAtts(time,(/"_FillValue"/))
		time@timezone	 = "Philippine Time"

		tasC_daily&time := time
		refevt&time  	:= time
		tasminC_daily&time := time
		tasmaxC_daily&time  := time
		rhum_daily&time := time
		windspeed_daily&time  := time
		u10_daily&time  := time
		v10_daily&time  := time
		ps_daily&time   := time
		netrad&time     := time
		pr_daily&time   := time
		

		print("writing GFS forecast of "+FCSTymd+hour+" daily time series to netcdf file ...")
		vtimeY 		= cd_string(tasC_daily&time(0),"%Y")
		vtimeYM		= cd_string(tasC_daily&time(0),"%Y%N")
		vtimeYMD	= cd_string(tasC_daily&time(0),"%Y%N%D")
		vtimeYMDend	= cd_string(tasC_daily&time(14),"%Y%N%D")
		outdir 		:= indir+vtimeY+"/"+vtimeYM+"/"+vtimeYMD+"/"
		ncoutfile 	:= "gfs4_"+project+"_"+FCSTymd+hour+"Zi_"+vtimeYMD+"-"+vtimeYMDend+"_daily" ;outfile
		system("mkdir -p "+outdir)  

		print("OutDIR : "+outdir)
		global_attributes_of_source_dataset = transfer_global_attributes(ftmp)
		collection = [/ refevt, tasC_daily, tasminC_daily, tasmaxC_daily, rhum_daily, windspeed_daily, \
						u10_daily, v10_daily, ps_daily, netrad, pr_daily, global_attributes_of_source_dataset/]
		collection_varnames = (/"refevt", "tas", "tasmin", "tasmax", "rhum", "windspeed", \
								"u10","v10","ps","netrad","pr","global_attributes_of_source_dataset"/)
		write_list_to_netcdf_standalone(collection,collection_varnames,outdir,ncoutfile) 
		delete([/collection,collection_varnames/])





		if (doRegrid.eq."True" .and. dimsizes(lat).gt.200) then

			ntas	= ESMF_regrid_with_weights(tasC_daily,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(ntas&time,(/ "_FillValue" /))
			ntasmin	= ESMF_regrid_with_weights(tasminC_daily,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(ntasmin&time,(/ "_FillValue" /))
			ntasmax	= ESMF_regrid_with_weights(tasmaxC_daily,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(ntasmax&time,(/ "_FillValue" /))
			nrhum	= ESMF_regrid_with_weights(rhum_daily,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(nrhum&time,(/ "_FillValue" /))
			nwindspeed	= ESMF_regrid_with_weights(windspeed_daily,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(nwindspeed&time,(/ "_FillValue" /))
			nu10	= ESMF_regrid_with_weights(u10_daily,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(nu10&time,(/ "_FillValue" /))
			nv10	= ESMF_regrid_with_weights(v10_daily,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(nv10&time,(/ "_FillValue" /))
			nnetrad	= ESMF_regrid_with_weights(netrad,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(nnetrad&time,(/ "_FillValue" /))
			nps		= ESMF_regrid_with_weights(ps_daily,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(nps&time,(/ "_FillValue" /))
			nrefevt	= ESMF_regrid_with_weights(refevt,"/home/ammann/ET/gfs-hres_gfs_ET.nc",False)
;			delete_VarAtts(nrefevt&time,(/ "_FillValue" /))
			npr 	= ESMF_regrid_with_weights(pr_daily,"/home/ammann/ET/gfs-hres_gfs_ET_for_pr.nc",False)
;			delete_VarAtts(npr&time,(/ "_FillValue" /))

;			print("writing updated daily data to netcdf file ...")
			ncoutfile   := ncoutfile+"_gfs-grid"
			global_attributes_of_source_dataset = transfer_global_attributes(ftmp)
			collection = [/ntas,ntasmin,ntasmax,nrhum,nwindspeed,npr,nrefevt,nnetrad,nps,nu10,nv10,global_attributes_of_source_dataset/]
			collection_varnames =  (/"tas","tasmin","tasmax","rhum","windspeed","pr","refevt","netrad","ps","n10","v10",\
									 "global_attributes_of_source_dataset"/)
			write_list_to_netcdf_standalone(collection,collection_varnames,outdir,ncoutfile)


			delete([/ncoutfile,collection,collection_varnames/])

		end if

		delete([/refevt, tasK,tasK_daily, tasC,tasC_daily, tasminK_daily,tasmaxK_daily, tasminC_daily,tasmaxC_daily,\
				 tasmin,tasmax,esAvg,ea,edef,nlwrad,nswrad,netrad, pr,pr_daily,u10_daily, v10_daily, \
				 q2,q2_daily, ps,ps_daily, u10,v10,windspeed,windspeed_daily,wind, rhum,rhum_daily,g,slp/])

		delete([/time,TIME,year,month,day,jday,ftmp,outdir/])

;		system("rm "+outdir+"*"+FCSTymdh+".nc")


	end do  ; end loop over fcstcycle
	end do  ; end loop over days


end


