load "/gpfs/home/ncar/ncl/verif_functions.ncl"
load "/gpfs/home/ncar/ncl/ncl_LoadRoutines.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"

begin

   do mloop=0,11

		hmonths := new(9,"string")
		month := mloop
		month@units = "months since 2020-01-01 00:00"
		monthtxt = cd_string(month,"%c")
		print("current month is "+(mloop+1)+" which is : "+monthtxt)

		month = month+1
		do j=0,8
			if (month.gt.12) then
				month=1
			end if
			hmonths(j) = cd_string(month,"%N")
			month = month+1
		end do
		print("Monthlist : "+hmonths)
    
		var			:= (/"tas","tasmin","tasmax","refevt","et5mm","rhum","pr","ps","windspeed","u10","v10"/)
		varunits	:= (/"C","C","C","mm/month","days","percent","mm/month","pa","m/s","m/s","m/s"/)

		cfsrdir		= "/gpfs/data/WRFdriver/cfsr/"
        cfsrfile	:= addfile(cfsrdir+"cfsr_pagasa_1982-2009_cfs-grid_monthly.nc","r")
		lat			 = cfsrfile->lat
		lon			 = cfsrfile->lon

;       read climatology of reanalysis
		climfile	:= addfile(cfsrdir+"cfsr_pagasa_1982-2009_cfs-grid_monthly-climatology.nc","r")


		hcstdir 	= "/gpfs/data/WRFdriver/cfs/hindcast/"
        
		dimhmonths	:= dimsizes(hmonths)

		time		:= ispan(0,dimhmonths-1,1)
		time!0		 = "time"
		time&time	 = time
		time@units 	 = "months since 2020-"+hmonths(0)+"-15 00:00"

		outdir		:= "/gpfs/data/WRFdriver/cfs/verification/"


		do v=0,dimsizes(var)-1

			; read variable from reanalysis (observational reference)
			cfsret	  := cfsrfile->$var(v)$
			; read variable from reanalysis climatology
			climvar	   = climfile->$var(v)$

			bias = new((/dimsizes(time),dimsizes(lat),dimsizes(lon)/),"float",1.e20)
			bias!0					= "time"
			bias!1					= "lat"
			bias!2					= "lon"
			bias&time				= time
			bias&lat				= lat
			bias&lon				= lon
			copy_VarAtts(var(v),bias)

			percentbias 			= bias
			percentbias@long_name 	= "percentbias"
			percentbias@units 		= "percent"		

			rmse					= bias
			rmse@long_name			= "root-mean-squared-error"
			rmse@units				= varunits(v)

			acc						= bias
			acc@long_name			= "anomaly-correlation-coefficient"
			acc@units				= "unitless"

			do month=0,dimsizes(hmonths)-1

				curmonth = stringtoint(hmonths(month)) - 1	
                        
				; read hindcast for lead month
				infile	:= addfile(hcstdir+"cfsv2_pagasa_hcast_"+monthtxt+"IC_"+hmonths(month)+"_1982-2009.nc","r")
				hrefevt	:= infile->$var(v)$
				hdim 	:= dimsizes(hrefevt)

				; read cfsr - reanalysis for the month
				rrefevt := cfsret(curmonth::12,:,:)

				;temporal alignment
				href 	:= hrefevt(0:hdim(0)-2,:,:)
				rref 	:= href
				ahref 	:= href
				arref 	:= href
				do i=0,dimsizes(href&time)-1
					idx 	:= ind(href&time(i).eq.rrefevt&time)
					rref(i,:,:)		= (/ rrefevt(idx,:,:) /)
					rref&time(i) 	= href&time(i)
					arref(i,:,:)	= rref(i,:,:) - climvar(curmonth,:,:)
					ahref(i,:,:)	= href(i,:,:) - climvar(curmonth,:,:)
				end do

				;compute bias
				bias(month,:,:)			= (/ verif_bias(href,rref) /)

				;compute percent-bias
				percentbias(month,:,:)	= (/ verif_percentbias(href,rref) /)

				;compute rmse
				rmse(month,:,:)			= (/ verif_rmse(href,rref) /)			

				;compute anomaly corretion
				acc(month,:,:)			= (/ verif_acc(ahref,arref) /)

			end do				

			percentbias = where(percentbias.gt.200. .or. percentbias.lt.-200.,percentbias@_FillValue,percentbias)
			acc         = where(acc.gt.2.,1.,acc)
			acc         = where(acc.lt.-2.,-1.,acc)
			bias        = where(bias.gt.1000. .or. bias.lt.-1000.,bias@_FillValue,bias)
				
			ncoutfile := "cfsv2_pagasa_verif_"+monthtxt+"IC_"+hmonths(0)+"-"+hmonths(dimsizes(hmonths)-1)+"_"+var(v) ;outfile
			global_attributes_of_source_dataset = transfer_global_attributes(infile)
			collection := [/ rmse,bias,percentbias,acc,global_attributes_of_source_dataset/]
			collection_varnames = (/"RMSE","BIAS","PercentBIAS","ACC","global_attributes_of_source_dataset"/)
			write_list_to_netcdf_standalone(collection,collection_varnames,outdir,ncoutfile) 

		end do

	end do
end

