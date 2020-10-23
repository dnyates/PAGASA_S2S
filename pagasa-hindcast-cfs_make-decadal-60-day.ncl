load "/home/ammann/ncl/ncl_LoadRoutines.ncl"  
load "/home/ammann/ET/CFS_monthly_indicator_functions.ncl"  

function calculate_decadal_values(var,calc)
begin

	decade = new((/6,dimsizes(var&lat),dimsizes(var&lon)/),"float",-1.e20)
	decade!0 	= "time"
	decade!1 	= "lat"
	decade!2 	= "lon"
	decade&time	= todouble(fspan(1,6,6))
	decade&lat	= var&lat
	decade&lon	= var&lon
	copy_VarAtts(var,decade)

	do dloop=0,5
		if (calc.eq."avg") then
			decade(dloop,:,:) 	= dim_avg_n(var(dloop*10:(dloop*10)+9,:,:),0)
		else if (calc.eq."sum") then
			decade(dloop,:,:) = dim_sum_n(var(dloop*10:(dloop*10)+9,:,:),0)
		end if 
		end if
		decade&time(dloop) 	= var&time(dloop*10) 
	end do
	return(decade)
end



function remove_atts(var)
begin
	delete(var@NCL_tag)
	var@time = 1
	delete(var@time)
	return(var)
end

;load "~/ET/module_monthly_indicator_functions.ncl"  
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"


;**********************************************************************
; Main Code
;**********************************************************************

begin

;	indir		= "/d3/hydrofcst/overtheloop/data/cfs/"		; on hydro-c1
;	indir		= "/glade/scratch/ammann/cfsv2/"			; on casper / cheyenne

	project		= "pagasa"
	FCSTtype	= "cfs"

;       rootdir		= "/glade/scratch/ammann/cfsv2/hindcast/"			; on casper / cheyenne
	rootdir		= "/d3/hydrofcst/overtheloop/pagasa/cfs/hindcast/"			; on casper / cheyenne        
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
		FCSTymd		:= FCSTyear+FCSTmonth+FCSTday

		dailyfile  	:= 	systemfunc("ls "+outdir+"cfsv2_"+project+"_"+FCSTymdh+"Zi_"+FCSTymd+"_*60day.nc")

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
		tas_decade		:= calculate_decadal_values(tas,"avg")
		tas_decade		 = remove_atts(tas_decade)
		tasmin 			:= ftmp->tasmin(:,{LatMin:LatMax},{LonMin:LonMax})
		tasmin_decade	:= calculate_decadal_values(tasmin,"avg")
		tasmin_decade	 = remove_atts(tasmin_decade)
		tasmax 			:= ftmp->tasmax(:,{LatMin:LatMax},{LonMin:LonMax})
		tasmax_decade	:= calculate_decadal_values(tasmax,"avg")
		tasmax_decade	 = remove_atts(tasmax_decade)
		refevt			:= ftmp->refevt(:,{LatMin:LatMax},{LonMin:LonMax})
		refevt_decade	:= calculate_decadal_values(refevt,"sum")
		refevt_decade	 = remove_atts(refevt_decade)
		rhum			:= ftmp->rhum(:,{LatMin:LatMax},{LonMin:LonMax})
		rhum_decade		:= calculate_decadal_values(rhum,"avg")
		rhum_decade		 = remove_atts(rhum_decade)
		pr				:= ftmp->pr(:,{LatMin:LatMax},{LonMin:LonMax})
		pr_decade		:= calculate_decadal_values(pr,"sum")
		pr_decade		 = remove_atts(pr_decade)
		ps				:= ftmp->ps(:,{LatMin:LatMax},{LonMin:LonMax})
		ps_decade		:= calculate_decadal_values(ps,"avg")
		ps_decade		 = remove_atts(ps_decade)
		windspeed		:= ftmp->windspeed(:,{LatMin:LatMax},{LonMin:LonMax})
		windspeed_decade	:= calculate_decadal_values(windspeed,"avg")
		windspeed_decade	 = remove_atts(windspeed_decade)
		u10				:= ftmp->u10(:,{LatMin:LatMax},{LonMin:LonMax})
		u10_decade		:= calculate_decadal_values(u10,"avg")
		u10_decade		 = remove_atts(u10_decade)
		v10				:= ftmp->v10(:,{LatMin:LatMax},{LonMin:LonMax})
		v10_decade		:= calculate_decadal_values(v10,"avg")
		v10_decade		 = remove_atts(v10_decade)

		;compute ET threshold exceedance
		et5mm_decade	:= compute_decadal_et5mm(refevt)
		et5mm_decade	 = remove_atts(et5mm_decade)

		time_decade		 = refevt_decade&time
		dtime			 = dimsizes(time_decade)
                
; testing time variable
;	print("*************************************")
;	print("Current Forecast : "+FCSTinit+"-"+hour)
;	tdim = dimsizes(refevt_monthly&time)
;	mtime = refevt_monthly&time
;	do tloop=0,3
;		print(tloop+" : "+cd_string(mtime(tloop),"%Y-%N-%D %H")+"   "+cd_string(mtime(tdim-tloop-1),"%Y-%N-%D %H"))
;	end do


		if (dtime.lt.6) then
			print("*******************************************************")
			print(" incomplete forecast : skipping "+FCSTymd+"-"+hour)
			print("*******************************************************")

		else
			YYYYMMst = cd_string(refevt&time(0),"%Y%N%D")
			YYYYMMed = cd_string(refevt&time(59),"%Y%N%D")
		
			ncoutfile = "cfsv2_"+project+"_"+FCSTymd+hour+"Zi_"+YYYYMMst+"_"+YYYYMMed+"_60day" ;outfile
			global_attributes_of_source_dataset = transfer_global_attributes(ftmp)
			collection = [/	refevt_decade,tas_decade,tasmin_decade,tasmax_decade,et5mm_decade,rhum_decade,pr_decade,\
							ps_decade,windspeed_decade,u10_decade,v10_decade,global_attributes_of_source_dataset/]
			collection_varnames = (/"refevt","tas","tasmin","tasmax","et5mm","rhum","pr",\
							"ps","windspeed","u10","v10","global_attributes_of_source_dataset"/)
			write_list_to_netcdf_standalone(collection,collection_varnames,outdir,ncoutfile) 
		end if  

		end do
	end do


end


