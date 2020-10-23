load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"

begin

varlist = (/ "refevt","tas","tasmin","tasmax","pr","rhum","et5mm","ps","windspeed","u10","v10" /)
;indir 	= "/glade/scratch/ammann/cfsv2/hindcast/pagasa/"
indir 	= "/d3/hydrofcst/overtheloop/pagasa/cfs/hindcast/pagasa/"
project = "pagasa"
monstr  = (/ "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec" /)

do month=1,12

	MM = tostring_with_format(month,"%2.2d")

	flist	= systemfunc("cd "+ indir + "; ls -f cfsv2_*_monthly.nc")
	fparts	= str_split_by_length(flist,(/13,4,2,4,2,4,11/))    ; et: 9  ;global: 13
;	fparts	= str_split_by_length(flist,(/13,13,4,2,4,11/))    ; et: 9  ;global: 13

	mlist   = fparts(:,2)
;print("parts "+fparts)
;print("mlist "+mlist)
;exit
	fselect = ind(mlist.eq.MM)
	if (any(ismissing(fselect))) then
		nselect = 0
		fselect = -9
	else
		nselect = dimsizes(fselect)
	end if

	do var=0,dimsizes(varlist)-1
		
		newvar 	= new((/nselect,9,31,48/),"float",1.e20)    ;pagasa
;		newvar 	= new((/nselect,9,27,38/),"float",1.e20)    ;et
;		newvar 	= new((/nselect,9,190,384/),"float",1.e20)	;global
		ntime	= new((/nselect,9/),"double")
		do i=0,nselect-1
			fin := addfile(indir+flist(fselect(i)),"r")
			readvar 		= fin->$varlist(var)$
			newvar(i,:,:,:) = readvar
;			newvar(i,:,:,:) = fin->$varlist(var)$
			ntime(i,:) 		= fin->time
		end do
		lat = fin->lat ;itude
		lon = fin->lon ;gitude

		do i=0,8
			outvar 		= (/ newvar(:,i,:,:) /)
			outvar!0 	= "time"
			outvar!1 	= "lat"
			outvar!2 	= "lon"
			outvar&time = ntime(:,i)
			outvar&lat  = lat
			outvar&lon 	= lon
			outvar@units 		= readvar@units
			outvar@long_name 	= readvar@long_name
			if (.not.isatt(outvar,"_FillValue")) then
				outvar@_FillValue	= 1.e20
			end if
			if (isatt(readvar,"level")) then
				outvar@level		= readvar@level
			end if
			if (varlist(var).eq."windspeed") then
				outvar@level		= "10.f"
			end if
			if (isatt(readvar,"parameters")) then
				outvar@parameters		= readvar@parameters
			end if
;			copy_VarAtts(readvar,outvar)
			delete_VarAtts(outvar&time,(/"_FillValue"/))
  
			LeadMonth = month+i+1
			if (LeadMonth.gt.12) then
				LeadMonth = LeadMonth - 12
			end if
			FCSTmonth = tostring_with_format(LeadMonth,"%2.2d")			
			ncoutfile = "cfsv2_"+project+"_"+varlist(var)+"_hcst_"+monstr(month-1)+"IC_"+FCSTmonth+"_1982-2009"


print("write output : "+ncoutfile)
			global_attributes_of_source_dataset = transfer_global_attributes(fin)
			collection = [/outvar,global_attributes_of_source_dataset/]
			collection_varnames = (/varlist(var),"global_attributes_of_source_dataset"/)
			write_list_to_netcdf_standalone(collection,collection_varnames,indir,ncoutfile) 
			delete([/ncoutfile,collection,collection_varnames/])

			delete([/outvar/])
		end do			
		delete([/readvar/])

	end do

;combine for each lead-time all variables into a single file associated with given monthly Initial Conditions

	do olp=0,8  
		LeadMonth := month+olp+1
		if (LeadMonth.gt.12) then
			LeadMonth = LeadMonth - 12
		end if
		FCSTmonth := tostring_with_format(LeadMonth,"%2.2d")			

		outfile = "cfsv2_"+project+"_hcast_"+monstr(month-1)+"IC_"+FCSTmonth+"_1982-2009.nc"
		system("mv "+indir+"cfsv2_"+project+"_"+varlist(0)+"_hcst_"+monstr(month-1)+"IC_"+FCSTmonth+"_*.nc  "+indir+outfile)
		do vlp=1,dimsizes(varlist)-1
			system("ncks -h -A "+indir+"cfsv2_"+project+"_"+varlist(vlp)+"_hcst_"+monstr(month-1)+"IC_"+FCSTmonth+"_*.nc  "+indir+outfile)
			system("rm "+indir+"cfsv2_"+project+"_"+varlist(vlp)+"_hcst_"+monstr(month-1)+"IC_"+FCSTmonth+"_*.nc")
		end do
	end do

	delete([/fselect,nselect,newvar,ntime,FCSTmonth/])

	
end do

;system("rm "+indir+"cfsv2_*_monthly.nc")

end

