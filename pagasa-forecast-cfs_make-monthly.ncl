load "/gpfs/home/ncar/ncl/ncl_LoadRoutines.ncl"  
load "/gpfs/home/ncar/tmp/pagasa_transfer/CFS_monthly_indicator_functions.ncl"  
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

	basedir		= "/gpfs/data/"
;	basedir		= "/gpfs/home/ncar/test/"
	indir		= basedir+"WRFdriver/cfs/"
	project		= "pagasa"
	FCSTtype	= "cfs"
	forceOverwrite  = False 
 


; check if month or specific day provided

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

; calculate next month for forecast range:
        monnow      = toint(FCSTmonth)
        nextmonth  := monnow + 1
        FCSTnextmonth = tostring_with_format(nextmonth,"%2.2d")
        FCSTyyyynn  = FCSTyear+FCSTnextmonth

        ndays = dimsizes(dailydir)


; loop over all available days

	do CFSdays=0,ndays-1

		outdir		= dailydir(CFSdays)+"/"

; collect ensemble list for 
		ensfiles := systemfunc("ls -f "+outdir+"cfs*_daily.nc")
		if(all(ismissing(ensfiles))) then
			print("******* No Forecasts found for this Day : "+dailydir(CFSdays)+" *********")
			continue
		else 
			ncycles := dimsizes(ensfiles)
			print("Ensemble files found: "+ensfiles)
		end if


		basepathposition 	= str_fields_count(indir,"/") 		; place pointer to name of daily cfs file
		monthfilesposition	= basepathposition + 4

		do loop=0,dimsizes(ensfiles)-1


			fpart	 = str_get_field(ensfiles(loop),monthfilesposition,"/")		; on hydro-c1
			zdate	:= str_get_field(fpart,3,"_")
			ydate	:= str_split_by_length(zdate,(/4,2,2,2/))
			hour	 = ydate(3)

			if (CFSprocess.eq."monthly") then	
				FCSTday 	:= ydate(2) ;tostring_with_format(ydate(2),"%2.2d")
				FCSTymd 	 = FCSTyear+FCSTmonth+FCSTday
			end if 
	
			fday = tointeger(FCSTday)
			dailyfile  	:= 	systemfunc("ls "+dailydir(CFSdays)+"/cfsv2_"+project+"_"+FCSTymd+hour+"Zi_"+FCSTyyyynn+"-*_monthly.nc")

			if (isfilepresent(dailyfile)) then
				if (forceOverwrite) then
					print("FCST-cycle already processed: "+dailyfile+". Re-processing ...")
				else
					print("FCST-cycle already procesed : "+dailyfile+". Proceeding to next ...")
					continue
				end if
			end if


			print("Processing Forecast : "+FCSTymd+"-"+hour+"z")
			ftmp := addfile(ensfiles(loop),"r")
	
			tas 			:= ftmp->tas
			tas_monthly		:= calculate_monthly_values(tas,"avg",0,False)

			tasmin 			:= ftmp->tasmin
			tasmin_monthly	:= calculate_monthly_values(tasmin,"avg",0,False)

			tasmax 			:= ftmp->tasmax			
			tasmax_monthly	:= calculate_monthly_values(tasmax,"avg",0,False)	

			refevt			:= ftmp->refevt
			refevt_monthly	:= calculate_monthly_values(refevt,"sum",0,False)

			rhum			:= ftmp->rhum
			rhum_monthly	:= calculate_monthly_values(rhum,"avg",0,False)

			windspeed		:= ftmp->windspeed
			windspeed_monthly := calculate_monthly_values(windspeed,"avg",0,False)
			u10				:= ftmp->u10
			u10_monthly 	:= calculate_monthly_values(u10,"avg",0,False)
			v10				:= ftmp->v10
			v10_monthly 	:= calculate_monthly_values(v10,"avg",0,False)

			pr				:= ftmp->pr
			pr_monthly		:= calculate_monthly_values(pr,"sum",0,False)
			pr_monthly@long_name = "monthly precipitation sum"
			pr_monthly@units = "mm"

			;compute ET threshold exceedance
			et5mm_monthly	:= compute_monthly_et5mm(refevt)



			time_monthly		:= refevt_monthly&time
			dtime				 = dimsizes(time_monthly)
;			print("Dim-Size of time : "+dtime)
			if (dtime.lt.10) then
				print("*******************************************************")
				print(FCSTymd+"-"+hour+" : incomplete forecast : skipping "+FCSTymd+"-"+hour)
				print("              cleaning up archive by removing incomplete data ")
				print("*******************************************************")
				system("rm "+ensfiles(loop)+"  "+outdir+"/cfsv2_"+project+"_"+FCSTymd+"_"+hour+"z.nc")

			else
				;subsetting only full months: start with next calendar month
				year			= tointeger(FCSTyear)
				year@calendar	= "standard"
				month			= tointeger(FCSTmonth)
				day				= tointeger(FCSTday)
				lastofmonth		= days_in_month(year,month)

				firstmonth = 1
				lastmonth  = 9

				refevt_monthly		:= refevt_monthly(firstmonth:lastmonth,:,:)
				refevt_monthly		 = remove_atts(refevt_monthly)
				tas_monthly			:= tas_monthly(firstmonth:lastmonth,:,:)
				tas_monthly			 = remove_atts(tas_monthly)
				tasmin_monthly		:= tasmin_monthly(firstmonth:lastmonth,:,:)
				tasmin_monthly		 = remove_atts(tasmin_monthly)
				tasmax_monthly		:= tasmax_monthly(firstmonth:lastmonth,:,:)
				tasmax_monthly		 = remove_atts(tasmax_monthly)
				windspeed_monthly	:= windspeed_monthly(firstmonth:lastmonth,:,:)
				windspeed_monthly	 = remove_atts(windspeed_monthly)
				u10_monthly			:= u10_monthly(firstmonth:lastmonth,:,:)
				u10_monthly			 = remove_atts(u10_monthly)
				v10_monthly			:= v10_monthly(firstmonth:lastmonth,:,:)
				v10_monthly			 = remove_atts(v10_monthly)
				pr_monthly			:= pr_monthly(firstmonth:lastmonth,:,:)
				pr_monthly			 = remove_atts(pr_monthly)
				rhum_monthly		:= rhum_monthly(firstmonth:lastmonth,:,:)
				rhum_monthly		 = remove_atts(rhum_monthly)
				et5mm_monthly		:= et5mm_monthly(firstmonth:lastmonth,:,:)
				et5mm_monthly		 = remove_atts(et5mm_monthly)	

				time_monthly		:= refevt_monthly&time
				dtime				 = dimsizes(time_monthly)
				YYYYMMst = cd_string(refevt_monthly&time(0),"%Y%N")
    	        YYYYMMed = cd_string(refevt_monthly&time(dtime-1),"%Y%N")
		
				ncoutfile = "cfsv2_"+project+"_"+FCSTymd+hour+"Zi_"+YYYYMMst+"-"+YYYYMMed+"_monthly" ;outfile
				global_attributes_of_source_dataset = transfer_global_attributes(ftmp)
				collection = [/	refevt_monthly,tas_monthly,tasmin_monthly,tasmax_monthly,windspeed_monthly,et5mm_monthly, \
								u10_monthly,v10_monthly,rhum_monthly,pr_monthly,global_attributes_of_source_dataset/]
				collection_varnames = (/"refevt","tas","tasmin","tasmax","windspeed","et5mm",\
										"u10","v10","rhum","pr","global_attributes_of_source_dataset"/)
				write_list_to_netcdf_standalone(collection,collection_varnames,outdir,ncoutfile) 
			end if  

		end do
	end do


end


