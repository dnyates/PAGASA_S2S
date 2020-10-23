load "/gpfs/home/ncar/ncl/verif_functions.ncl"
load "/gpfs/home/ncar/ncl/ncl_LoadRoutines.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"

begin

   monthtxt = (/"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)

   do mloop=0,11

		

		hdecade := new(6,"string")
		do j=0,5
			hdecade(j) = tostring_with_format((j+1),"%2.2d")
		end do
;		print("Decades - List : "+hdecade)
    
		var			:= (/"tas","tasmin","tasmax","refevt","rhum","pr","ps","windspeed","u10","v10"/)
		varunits	:= (/"C","C","C","mm/decade","percent","mm/decade","pa","m/s","m/s","m/s"/)

        cfsrdir     := "/gpfs/data/WRFdriver/cfsr/"
        cfsrfile	:= addfile(cfsrdir+"cfsr_pagasa_1982-2009_cfs-grid_daily.nc","r")
		lat			 = cfsrfile->lat
		lon			 = cfsrfile->lon

;       read climatology of reanalysis
		climfile	:= addfile(cfsrdir+"cfsr_pagasa_1982-2009_daily-stats.nc","r")

;       read hindcasts
		hcstdir		:= "/gpfs/data/WRFdriver/cfs/hindcast/"        
		dimhdecade	:= dimsizes(hdecade)

		time		:= ispan(0,50,10)
		time!0		 = "time"
		time&time	 = time
		unitstring	 = "days since 2020-"+tostring_with_format((mloop+1),"%2.2d")+"-01 00:00"
		time@units	 = unitstring

		outdir		:= "/gpfs/data/WRFdriver/cfs/verification/"


		do v=0,dimsizes(var)-1

			; read variable from reanalysis (observational reference)
			cfsret	  				:= cfsrfile->$var(v)$
			rtime					:= cd_string(cfsret&time,"%Y-%N-%D")


			; read variable from reanalysis climatology
			climstat   				:= climfile->$var(v)$
			climvar	   				:= climstat(3,:,:,:)
			dimclim					:= dimsizes(climvar)
			climloop				:= new((/dimclim(0)*2,dimclim(1),dimclim(2)/),"float")
			climloop!0				 = "day"
			climloop!1				 = "lat"
			climloop!2				 = "lon"
			doubletime				 = dimclim(0)*2
			climloop&day			 = ispan(0,doubletime-1,1)
			climloop&lat			 = climvar&lat
			climloop&lon			 = climvar&lon
			climloop(0:dimclim(0)-1,:,:) = (/ climvar /)
			climloop(dimclim(0):,:,:)   = (/ climvar /)

			; define different verification variables
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

			do decade=0,5
                        
				; read hindcast for lead month
				infile	:= addfile(hcstdir+"cfsv2_pagasa_hcast_"+monthtxt(mloop)+"IC_"+hdecade(decade)+"-decade_1982-2009.nc","r")
				hrefevt	:= infile->$var(v)$
				hdim 	:= dimsizes(hrefevt)

				;setup output arrays for hindcast and reanalysis pairs
				href 	:= hrefevt(0:hdim(0)-2,:,:)
				rref 	:= href
				ahref 	:= href
				arref 	:= href
				cref 	:= href
				
				do i=0,dimsizes(href&time)-1
					htime	:= cd_string(href&time(i),"%Y-%N-%D")
					idx 	:= ind(rtime.eq.htime)
					jyear	:= cd_string(href&time(i),"%Y")
					jmonth	:= cd_string(href&time(i),"%n")
					jday	:= cd_string(href&time(i),"%d")
					julday	:= day_of_year(tointeger(jyear),tointeger(jmonth),tointeger(jday))-1
					if (var(v).eq."pr" .or. var(v).eq."refevt") then
						rref(i,:,:)	= (/ dim_sum_n(cfsret(idx:idx+9,:,:),0) /)
						cref(i,:,:) = dim_sum_n(climloop(julday:julday+9,:,:),0)
					else						
						rref(i,:,:) = (/ dim_avg_n(cfsret(idx:idx+9,:,:),0) /)
						cref(i,:,:) = dim_avg_n(climloop(julday:julday+9,:,:),0)
					end if
					arref(i,:,:)	= rref(i,:,:) - cref(i,:,:)
					ahref(i,:,:)	= href(i,:,:) - cref(i,:,:)
				end do

				;compute bias
				bias(decade,:,:)		= (/ verif_bias(href,rref) /)

				;compute percent-bias
				percentbias(decade,:,:)	= (/ verif_percentbias(href,rref) /)

				;compute rmse
				rmse(decade,:,:)		= (/ verif_rmse(href,rref) /)			

				;compute anomaly correlation
				acc(decade,:,:)			= (/ verif_acc(ahref,arref) /)

			end do				

			percentbias = where(percentbias.gt.200. .or. percentbias.lt.-200.,percentbias@_FillValue,percentbias)
			acc         = where(acc.gt.2.,1.,acc)
			acc         = where(acc.lt.-2.,-1.,acc)
			bias        = where(bias.gt.1000. .or. bias.lt.-1000.,bias@_FillValue,bias)
	
			print("outfile: cfsv2_pagasa_verif_"+monthtxt(mloop)+"IC_"+hdecade(0)+"-"+hdecade(dimsizes(hdecade)-1)+"_"+var(v))			
			ncoutfile := "cfsv2_pagasa_verif_"+monthtxt(mloop)+"IC-decade_"+hdecade(0)+"-"+hdecade(dimsizes(hdecade)-1)+"_"+var(v) ;outfile
			global_attributes_of_source_dataset = transfer_global_attributes(infile)
			global_attributes_of_source_dataset@author = "Caspar Ammann"
			collection := [/ rmse,bias,percentbias,acc,global_attributes_of_source_dataset/]
			collection_varnames = (/"RMSE","BIAS","PercentBIAS","ACC","global_attributes_of_source_dataset"/)
			write_list_to_netcdf_standalone(collection,collection_varnames,outdir,ncoutfile) 

		end do
	end do I8W@ff13s!@#
end

