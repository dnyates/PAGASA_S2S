load "CFS_monthly_indicator_functions.ncl"
;load "~/ET/module_monthly_indicator_functions.ncl"
  

begin

	project 	= getenv("project")
	indir 		= getenv("indir") ;"/glade/scratch/ammann/CFSR/daily/test/"

	varlist 	= (/ "refevt", "tas","tasmin","tasmax","rhum","windspeed","u10","v10","pr","ps","netrad" /)

	stat		= ispan(0,6,1)
	stat!0		= "stat"
	stat&stat	= stat
	stat@units	= "min 10th 25% 50% 75% 90th max"


	time		= ispan(0,365,1)
	time!0 		= "time"
	time&time 	= time
	time@calendar = "standard"
	time@units 	= "day of year"


	do loop=0,dimsizes(varlist)-1  			; loop over varlist 

		print("processing ... : "+varlist(loop))

		sourcefile := "cfsr_"+project+"_1982-2009_cfs-grid_daily.nc"
;		sourcefile := varlist(loop)+"_"+project+"_1982-2009_daily.nc" 
		infile  := addfile(indir+sourcefile,"r")
		var 	:= infile->$varlist(loop)$
		lat		= infile->lat
		lon		= infile->lon

		time    := infile->time                                   
		TIME    := cd_calendar(time, 0)             ; type float 
		year    := toint( TIME(:,0) )               ; toint strips meta data
		month   := toint( TIME(:,1) )
		day     := toint( TIME(:,2) ) 
		delete(time)
                                                                 ; check for calendar attribute
		if (isatt(TIME,"calendar")) then           ; default is gregorian
			year@calendar = TIME@calendar         
		end if

		ddd     = day_of_year(year, month, day) 
		yyyyddd = year*1000 + ddd                                    ; needed for input
		if (isatt(year,"calendar")) then           ; default is gregorian
			ddd@calendar 	 = year@calendar  
			yyyyddd@calendar = ddd@calendar  
		end if

		time	 	= ispan(1,366,1)
		time!0		= "time"
		time&time	= time
		time@units	= "day of year"
		time@calendar = "standard"

		locnew := new((/30,dimsizes(time),dimsizes(lat),dimsizes(lon)/),"float")
		locnew@calendar = "standard"
		do i=0,364
			do j=0,dimsizes(lat)-1
			do k=0,dimsizes(lon)-1
				locnew(:,i,j,k) = stat_dispersion(var(i::365,j,k),False)
			end do
			end do
		end do
		locnew(:,365,:,:) = ( locnew(:,364,:,:) + locnew(:,0,:,:) ) * 0.5
	

		varstat := new((/dimsizes(stat),dimsizes(time),dimsizes(lat),dimsizes(lon)/),"float")
		varstat!0 = "stat"
		varstat!1 = "time"
		varstat!2 = "lat"
		varstat!3 = "lon"
		varstat&stat = stat
		varstat&time = time
		varstat&lat  = lat
		varstat&lon	 = lon
		varstat@_FillValue = 1.e20

		varstat(0,:,:,:)   = (/ smthClmDayTLL(locnew(2,:,:,:),3)  /)  	; min ;5%
		varstat(1,:,:,:)   = (/ smthClmDayTLL(locnew(3,:,:,:),3)  /)	; 10%
		varstat(2,:,:,:)   = (/ smthClmDayTLL(locnew(6,:,:,:),3)  /)	; 25%
		varstat(3,:,:,:)   = (/ smthClmDayTLL(locnew(8,:,:,:),3)  /)	; 50%
		varstat(4,:,:,:)   = (/ smthClmDayTLL(locnew(10,:,:,:),3) /)	; 75%
		varstat(5,:,:,:)   = (/ smthClmDayTLL(locnew(13,:,:,:),3) /)	; 90%
		varstat(6,:,:,:)   = (/ smthClmDayTLL(locnew(14,:,:,:),3) /)	; max ;95%
		copy_VarAtts(var,varstat)


		system ("rm "+indir+varlist(loop)+"_"+project+"_1982-2009_daily-stats.nc")             ; remove any pre-existing file
		fout := addfile(indir+varlist(loop)+"_"+project+"_1982-2009_daily-stats.nc","c")

		setfileoption(fout,"DefineMode",True)
		fAtt                = True            ; assign file attributes
		fAtt@title         := "CFSR-smooth annual cycle climatology 1982-2009"  
		fAtt@source_file   := sourcefile
		fAtt@creation_date := systemfunc ("date")        
		fileattdef( fout, fAtt )            ; copy file attributes    

		dimNames = (/"stat", "time", "lat", "lon" /)  
		dimSizes = (/ dimsizes(stat), dimsizes(time), dimsizes(lat), dimsizes(lon) /) 
		dimUnlim = (/ False, False , False, False/)   
		filedimdef(fout,dimNames,dimSizes,dimUnlim)

		filevardef(fout, "stat" ,typeof(stat),getvardims(stat)) 
		filevardef(fout, "time" ,typeof(time),getvardims(time)) 
		filevardef(fout, "lat"  ,typeof(lat),getvardims(lat))                          
		filevardef(fout, "lon"  ,typeof(lon),getvardims(lon))                          
		filevardef(fout, varlist(loop) ,typeof(varstat)  ,getvardims(varstat))    

		filevarattdef(fout,varlist(loop),varstat)                           ; copy T attributes
		filevarattdef(fout,"stat" ,stat)                    ; copy time attributes
		filevarattdef(fout,"time" ,time)                    ; copy time attributes
		filevarattdef(fout,"lat"  ,lat)                     ; copy lat attributes
		filevarattdef(fout,"lon"  ,lon)                     ; copy lon attributes

		setfileoption(fout,"DefineMode",False)

		fout->stat   			= (/stat/)     
		fout->time   			= (/time/)     
		fout->lat    			= (/lat/)
		fout->lon    			= (/lon/) 
		fout->$varlist(loop)$	= varstat

		delete(time)

	; now geneatte monthly data
		print("... computing monthly ...")
		time 			= ispan(1,12,1)
		time!0			= "time"
		time&time		= time
		time@units		= "month of year"
		
		varmonthly 	 	= new((/dimsizes(stat),12,dimsizes(lat),dimsizes(lon)/),"float")
		varmonthly!0 	= "stat"
		varmonthly!1 	= "time"
		varmonthly!2 	= "lat"
		varmonthly!3 	= "lon"
		varmonthly&stat = stat
		varmonthly&time = ispan(1,12,1)
		varmonthly&lat  = lat
		varmonthly&lon	= lon
		varmonthly@_FillValue = 1.e20


	; separate monthly calculation by avg grou and "sum" group
		; sum group: precipitation, refevt
		if (varlist(loop).eq."refevt" .or. varlist(loop).eq."pr") then

			DPM = (/ 31,29,31,30,31,30,31,31,30,31,30,31 /)
			do i=0,dimsizes(stat)-1
				do j=0,11
					startD	= sum(DPM(0:j)) - DPM(j)
					endD	= sum(DPM(0:j)) - 1
					varmonthly(i,j,:,:) = dim_sum_n(varstat(i,startD:endD,:,:),0)
				end do
			end do
			; if refevt: compute indicator et5mm
			if (varlist(loop).eq."refevt") then
				et5mm_monthly = compute_monthly_et5mm(var)
				locnew := new((/30,12,dimsizes(lat),dimsizes(lon)/),"float")
				do i=0,11
					do j=0,dimsizes(lat)-1
					do k=0,dimsizes(lon)-1
						locnew(:,i,j,k) = stat_dispersion(et5mm_monthly(i::12,j,k),False)
					end do
					end do
				end do
				slist = (/ 2, 3, 6, 8, 10, 13, 14 /)			;"min 10% 25% 50% 75% 90% max"
				et5monthly = locnew(slist,:,:,:)
				copy_VarCoords(varmonthly,et5monthly)
				et5monthly@long_name = "number of days per month with refevt >5mm"
				et5monthly@_FillValue = 1.e20
			end if	
		else
			do i=0,dimsizes(stat)-1
				do j=0,11
					startD	= sum(DPM(0:j)) - DPM(j)
					endD	= sum(DPM(0:j)) - 1
					varmonthly(i,j,:,:) = dim_avg_n(varstat(i,startD:endD,:,:),0)
				end do
			end do
		end if
		copy_VarAtts(varstat,varmonthly)

		system ("rm "+indir+varlist(loop)+"_"+project+"_1982-2009_monthly-stats.nc")             ; remove any pre-existing file
		fout := addfile(indir+varlist(loop)+"_"+project+"_1982-2009_monthly-stats.nc","c")

		setfileoption(fout,"DefineMode",True)
		fAtt                = True            ; assign file attributes
		fAtt@title         := "CFSR monthly statistics of climatology 1982-2009"  
		fAtt@source_file   := sourcefile
		fAtt@creation_date := systemfunc ("date")        
		fileattdef( fout, fAtt )            ; copy file attributes    

		dimNames = (/"stat", "time", "lat", "lon" /)  
		dimSizes = (/ dimsizes(stat), dimsizes(time), dimsizes(lat), dimsizes(lon) /) 
		dimUnlim = (/ False, False , False, False/)   
		filedimdef(fout,dimNames,dimSizes,dimUnlim)

		filevardef(fout, "stat" ,typeof(stat),getvardims(stat)) 
		filevardef(fout, "time" ,typeof(time),getvardims(time)) 
		filevardef(fout, "lat"  ,typeof(lat),getvardims(lat))                          
		filevardef(fout, "lon"  ,typeof(lon),getvardims(lon))                          
		filevardef(fout, varlist(loop) ,typeof(varmonthly)  ,getvardims(varmonthly))    

		filevarattdef(fout,varlist(loop),varmonthly)                           ; copy T attributes
		filevarattdef(fout,"stat" ,stat)                    ; copy time attributes
		filevarattdef(fout,"time" ,time)                    ; copy time attributes
		filevarattdef(fout,"lat"  ,lat)                     ; copy lat attributes
		filevarattdef(fout,"lon"  ,lon)                     ; copy lon attributes
	
		if (varlist(loop).eq."refevt") then
			filevardef(fout, "et5mm" ,typeof(et5monthly)  ,getvardims(et5monthly))    
			filevarattdef(fout,"et5mm",et5monthly)                           ; copy T attributes
		end if

		setfileoption(fout,"DefineMode",False)

		fout->stat   			= stat     
		fout->time   			= time     
		fout->lat    			= lat
		fout->lon    			= lon 
		fout->$varlist(loop)$	= varmonthly
		if (varlist(loop).eq."refevt") then
			fout->et5mm			= et5monthly
		end if

		delete([/varstat,varmonthly/])
	end do

end


