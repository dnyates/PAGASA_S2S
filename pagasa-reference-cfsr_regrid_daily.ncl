load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"


begin

	regrid_indir 	= getenv("regrid_indir") 	;"/glade/scratch/ammann/CFSR/test/"
	regrid_infile 	= getenv("regrid_infile") ;"cfsr_et_tas_1982.nc"
;	regrid_indir 	= "/glade/scratch/ammann/CFSR/pagasa"
;	regrid_infile	= "cfsr_pagasa_tas_1982-2009.nc"

	print("Now regridding : "+regrid_indir+"/"+regrid_infile)
    fpath       = regrid_indir+"/"
	fname		= regrid_infile
	fnameshort	= str_sub_str(fname,".nc","")

	namesplit	= str_split_csv(fname,"_",2)
	invar		= namesplit(0,2)
	print("... variable : "+invar)


	sfile 				= addfile(fpath+"/"+fname,"r")
    var         		= sfile->$invar$
	ilat				= sfile->lat
	ilon				= sfile->lon

	refpath				= "/glade/scratch/ammann/CFSR/reference/"
	fref				= addfile(refpath+"cfs_pagasa_reference-grid.nc","r")
	lat					= fref->lat 
	lon					= fref->lon

    Opt                	= True
    Opt@Debug = True
    Opt@SrcFileName    	= "~/ET/cfsr_2_cfs_PAGASA_SCRIP.nc"
    Opt@SrcGridLat     	= ilat
    Opt@SrcGridLon     	= ilon
    Opt@DstFileName    	= "~/ET/cfs_PAGASA_Rectilinear.nc"
    Opt@WgtFileName    	= "~/ET/cfsr_cfs_PAGASA.nc"
    Opt@ForceOverwrite 	= True
;    Opt@SrcMask2D      = where(.not.ismissing(var(0,:,:)),1,0)

    Opt@DstGridLat     	= lat ;mlat
    Opt@DstGridLon     	= lon ;mlon

    Opt@SrcRegional    	= True             ; These are necessary
    Opt@DstRegional    	= True

	if (invar.eq."pr") then
	    Opt@InterpMethod   := "conserve" 	; "bilinear";"conserve"       ; Default is bilinear
	else
	    Opt@InterpMethod   := "bilinear"		;"conserve"       ; Default is bilinear
	end if

	vnew = ESMF_regrid(var,Opt)
	vnew = ESMF_regrid_with_weights(var,"~/ET/cfsr_cfs_PAGASA.nc",False)
	vnew@_FillValue = 1.e20
	delete_VarAtts(vnew&time,(/ "_FillValue" /))

	print("writing updated daily data to netcdf file ...")
	outpath		= fpath
	ncoutfile   = fnameshort+"_cfs-grid"
	global_attributes_of_source_dataset = transfer_global_attributes(sfile)
	collection = [/vnew,global_attributes_of_source_dataset/]
	collection_varnames = (/invar,"global_attributes_of_source_dataset"/)
	write_list_to_netcdf_standalone(collection,collection_varnames,outpath,ncoutfile)

end

