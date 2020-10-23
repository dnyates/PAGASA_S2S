load "/home/ammann/ncl/ncl_LoadRoutines.ncl"
load "/home/ammann/ET/CFS_monthly_indicator_functions.ncl"  
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"


function remove_atts(var)
begin
	delete(var@NCL_tag)
	var@time = 1
	delete(var@time)
	return(var)
end



;**********************************************************************
; Main Code
;**********************************************************************

begin

	project		= "pagasa"
	FCSTtype	= "cfs"

	rootdir		= "/d3/hydrofcst/overtheloop/pagasa/WRFdriver/cfs/hindcast/"
	indir		= rootdir+"global/"
	outdir		= rootdir+project+"/"

	forceOverwrite  = True 

	LatMin 		=  -5.
	LatMax		=  25.
	LonMin		=  95.
	LonMax		= 140.


; check if month or day provided
	do year=1982,2009

		do month=1,12

		FCSTyear 	= tostring(year)
		FCSTmonth 	= tostring_with_format(month,"%2.2d")
		FCSTyyyymm 	= FCSTyear+FCSTmonth

; calculate next month for forecast range:
        monnow      = month
        nextmonth  := monnow + 1
        FCSTnextmonth = tostring_with_format(nextmonth,"%2.2d")
        FCSTyyyynn  = FCSTyear+FCSTnextmonth

; collect ensemble list for 
		infile := systemfunc("ls -f "+indir+"cfs_"+FCSTyyyymm+"*Zi_daily.nc")
		if(all(ismissing(infile))) then
			print("******* No Forecasts found for this Day : "+FCSTyyyymm+" *********")
			continue
		end if

;		fpart	= str_get_field(ensfiles(loop),8,"/")		; on casper  / cheyenne
		fpart		:= str_get_field(infile,7,"/")		; on hydro-c1
		zdate		:= str_get_field(fpart,2,"_")
		ydate		:= str_split_by_length(zdate,(/4,2,2,2/))

		FCSTday 	:= ydate(2) ;tostring_with_format(ydate(2),"%2.2d")
		day			:= toint(FCSTday)
		FCSTymd 	:= FCSTyear+FCSTmonth+FCSTday
		hour		:= ydate(3)
		FCSTymdh    := FCSTyear+FCSTmonth+FCSTday+hour

;		if (day.le.14) then
;			dailyfile  	:= 	systemfunc("ls "+indir+"/cfsv2_"+project+"_"+FCSTymdh+"Zi_"+FCSTyyyymm+"-*_monthly.nc")
;		else
			dailyfile  	:= 	systemfunc("ls "+indir+"/cfsv2_"+project+"_"+FCSTymdh+"Zi_"+FCSTyyyynn+"-*_monthly.nc")
;		end if

		if (isfilepresent(dailyfile)) then
			if (forceOverwrite) then
				print("FCST-cycle already processed: "+dailyfile+". Re-processing ...")
			else
				print("FCST-cycle already procesed : "+dailyfile+". Proceeding to next ...")
				continue
			end if
		end if


		print("Processing Forecast : "+FCSTymd+"-"+hour+"z")
		ftmp := addfile(infile,"r")
	
		tas 			:= ftmp->tas(:,{LatMin:LatMax},{LonMin:LonMax})
		tas_monthly		:= calculate_monthly_values(tas,"avg",0,False)
		tasmin 			:= ftmp->tasmin(:,{LatMin:LatMax},{LonMin:LonMax})
		tasmin_monthly	:= calculate_monthly_values(tasmin,"avg",0,False)
		tasmax 			:= ftmp->tasmax(:,{LatMin:LatMax},{LonMin:LonMax})
		tasmax_monthly	:= calculate_monthly_values(tasmax,"avg",0,False)
		refevt			:= ftmp->refevt(:,{LatMin:LatMax},{LonMin:LonMax})
		refevt_monthly	:= calculate_monthly_values(refevt,"sum",0,False)
		rhum			:= ftmp->rhum(:,{LatMin:LatMax},{LonMin:LonMax})
		rhum_monthly	:= calculate_monthly_values(rhum,"avg",0,False)
		pr				:= ftmp->pr(:,{LatMin:LatMax},{LonMin:LonMax})
		pr_monthly		:= calculate_monthly_values(pr,"sum",0,False)
		ps				:= ftmp->ps(:,{LatMin:LatMax},{LonMin:LonMax})
		ps_monthly		:= calculate_monthly_values(ps,"avg",0,False)
		windspeed		:= ftmp->windspeed(:,{LatMin:LatMax},{LonMin:LonMax})
		windspeed_monthly	:= calculate_monthly_values(windspeed,"avg",0,False)
		u10				:= ftmp->u10(:,{LatMin:LatMax},{LonMin:LonMax})
		u10_monthly		:= calculate_monthly_values(u10,"avg",0,False)
		v10				:= ftmp->v10(:,{LatMin:LatMax},{LonMin:LonMax})
		v10_monthly		:= calculate_monthly_values(v10,"avg",0,False)


		;compute ET threshold exceedance
		et5mm_monthly	:= compute_monthly_et5mm(refevt)

		;subsetting only full months
;		if (day.le.14) then
;			firstmonth = 0
;		else
			firstmonth = 1
;		end if
		refevt_monthly          := refevt_monthly(firstmonth:,:,:)
		refevt_monthly			 = remove_atts(refevt_monthly)
		tas_monthly     	    := tas_monthly(firstmonth:,:,:)
		tas_monthly				 = remove_atts(tas_monthly)
		tasmin_monthly          := tasmin_monthly(firstmonth:,:,:)
		tasmin_monthly			 = remove_atts(tasmin_monthly)
		tasmax_monthly          := tasmax_monthly(firstmonth:,:,:)
		tasmax_monthly			 = remove_atts(tasmax_monthly)
		rhum_monthly       		:= rhum_monthly(firstmonth:,:,:)
		rhum_monthly		 	 = remove_atts(rhum_monthly)
		pr_monthly				:= pr_monthly(firstmonth:,:,:)
		pr_monthly				 = remove_atts(pr_monthly)
		et5mm_monthly           := et5mm_monthly(firstmonth:,:,:)
		et5mm_monthly			 = remove_atts(et5mm_monthly)
		ps_monthly				:= ps_monthly(firstmonth:,:,:)
		ps_monthly				 = remove_atts(ps_monthly)
		windspeed_monthly		:= windspeed_monthly(firstmonth:,:,:)
		windspeed_monthly		 = remove_atts(windspeed_monthly)
		u10_monthly				:= u10_monthly(firstmonth:,:,:)
		u10_monthly				 = remove_atts(u10_monthly)
		v10_monthly				:= v10_monthly(firstmonth:,:,:)
		v10_monthly				 = remove_atts(v10_monthly)

		time_monthly            := refevt_monthly&time
		dtime                    = dimsizes(time_monthly)
                
; testing time variable
;	print("*************************************")
;	print("Current Forecast : "+FCSTinit+"-"+hour)
;	tdim = dimsizes(refevt_monthly&time)
;	mtime = refevt_monthly&time
;	do tloop=0,3
;		print(tloop+" : "+cd_string(mtime(tloop),"%Y-%N-%D %H")+"   "+cd_string(mtime(tdim-tloop-1),"%Y-%N-%D %H"))
;	end do


		if (dtime.lt.9) then
			print("*******************************************************")
			print(" incomplete forecast : skipping "+FCSTymd+"-"+hour)
			print("*******************************************************")

		else
			YYYYMMst = cd_string(refevt_monthly&time(0),"%Y%N")
			YYYYMMed = cd_string(refevt_monthly&time(dtime-1),"%Y%N")
		
			ncoutfile = "cfsv2_"+project+"_"+FCSTymd+hour+"Zi_"+YYYYMMst+"-"+YYYYMMed+"_monthly" ;outfile
			global_attributes_of_source_dataset = transfer_global_attributes(ftmp)
			collection = [/	refevt_monthly,tas_monthly,tasmin_monthly,tasmax_monthly,et5mm_monthly,rhum_monthly,pr_monthly,\
							ps_monthly,windspeed_monthly,u10_monthly,v10_monthly,global_attributes_of_source_dataset/]
			collection_varnames = (/"refevt","tas","tasmin","tasmax","et5mm","rhum","pr",\
							"ps","windspeed","u10","v10","global_attributes_of_source_dataset"/)

			write_list_to_netcdf_standalone(collection,collection_varnames,outdir,ncoutfile) 
		end if  

		end do
	end do


end


