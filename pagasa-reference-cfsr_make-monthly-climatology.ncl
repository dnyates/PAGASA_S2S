load "~/ET/module_monthly_indicator_functions.ncl"  

begin

	namelist_path = getenv("project_namelist")
	cfsdir	= keyword_values( namelist_path, "cfsdir", 	"string" )
	infile	= keyword_values( namelist_path, "infile", 	"string" )
	outfile	= keyword_values( namelist_path, "outfile", "string" )
	vars	= keyword_values( namelist_path, "var"	 , 	"string" )

	infile  := addfile(cfsdir+outfile,"r")
	lat		= infile->lat
	lon		= infile->lon

	refevt_monthly	= infile->refevt
	refevt			= clmMonTLL(refevt_monthly)
	et5mm_monthly	= infile->et5mm
	et5mm			= clmMonTLL(et5mm_monthly)
	tas_monthly		= infile->tas
	tas				= clmMonTLL(tas_monthly)
	tasmin_monthly	= infile->tasmin
	tasmin			= clmMonTLL(tasmin_monthly)
	tasmax_monthly	= infile->tasmax
	tasmax			= clmMonTLL(tasmax_monthly)
	rhum_monthly	= infile->rhum
	rhum			= clmMonTLL(rhum_monthly)
	pr_monthly		= infile->pr
	pr				= clmMonTLL(pr_monthly)
	ps_monthly		= infile->ps
	ps				= clmMonTLL(ps_monthly)
	windspeed_monthly	= infile->windspeed
	windspeed			= clmMonTLL(windspeed_monthly)
	u10_monthly		= infile->u10
	u10				= clmMonTLL(u10_monthly)
	v10_monthly		= infile->v10
	v10				= clmMonTLL(v10_monthly)

	month			= refevt&month
	month!0			= "month"
	month&month		= month

	system ("rm "+cfsdir+"cfsr_pagasa_1982-2009_cfs-grid_monthly-climatology.nc")  
	fout := addfile(cfsdir+"cfsr_pagasa_1982-2009_cfs-grid_monthly-climatology.nc","c")

	setfileoption(fout,"DefineMode",True)
	fAtt                = True            ; assign file attributes
	fAtt@title         := "CFSR-monthly climatology 1982-2009"  
	fAtt@source_file   := outfile 
	fAtt@creation_date := systemfunc ("date")        
	fileattdef( fout, fAtt )            ; copy file attributes    

	dimNames = (/"month", "lat", "lon" /)  
	dimSizes = (/dimsizes(month), dimsizes(lat), dimsizes(lon) /) 
	dimUnlim = (/False , False, False/)   
	filedimdef(fout,dimNames,dimSizes,dimUnlim)

	filevardef(fout, "month" 	,typeof(month)	,getvardims(month)) 
	filevardef(fout, "lat"  	,typeof(lat)	,getvardims(lat))                          
	filevardef(fout, "lon"  	,typeof(lon)	,getvardims(lon))                          
	filevardef(fout, "refevt"	,typeof(refevt)	,getvardims(refevt))    
	filevardef(fout, "et5mm"	,typeof(et5mm)	,getvardims(et5mm))    
	filevardef(fout, "tas"		,typeof(tas)	,getvardims(tas))    
	filevardef(fout, "tasmin"	,typeof(tasmin)	,getvardims(tasmin))    
	filevardef(fout, "tasmax"	,typeof(tasmax)	,getvardims(tasmax))    
	filevardef(fout, "rhum"		,typeof(rhum)	,getvardims(rhum))    
	filevardef(fout, "pr"		,typeof(pr)		,getvardims(pr))    
	filevardef(fout, "ps"		,typeof(ps)		,getvardims(ps))    
	filevardef(fout, "windspeed",typeof(windspeed)	,getvardims(windspeed))    
	filevardef(fout, "u10"		,typeof(u10)	,getvardims(u10))    
	filevardef(fout, "v10"		,typeof(v10)	,getvardims(v10))    

;	filevarattdef(fout,"time" ,time)                    ; copy time attributes
;	filevarattdef(fout,"lat"  ,lat)                     ; copy lat attributes
;	filevarattdef(fout,"lon"  ,lon)                     ; copy lon attributes

	setfileoption(fout,"DefineMode",False)

	fout->month  	= month   
	fout->lat   	= lat  
	fout->lon   	= lon  
	fout->refevt	= refevt
	fout->et5mm		= et5mm
	fout->tas		= tas
	fout->tasmin	= tasmin
	fout->tasmax	= tasmax
	fout->rhum		= rhum
	fout->pr		= pr
	fout->ps		= ps
	fout->windspeed	= windspeed
	fout->u10		= u10
	fout->v10		= v10


end


