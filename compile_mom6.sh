#!/bin/bash
module purge
module load intel-mpi/intel/2018.3/64
module load intel/18.0/64/18.0.3.222
module load hdf5/intel-16.0/intel-mpi/1.8.16
module load netcdf/intel-16.0/hdf5-1.8.16/intel-mpi/4.4.0

#link datasets to current MOM6
if [ ! -e .datasets ]
then
    ln -s /scratch/gpfs/GEOCLIM/LRGROUP/datasets .datasets
fi

# compile label for bio or ocean-ice
# be careful with the compile label (clab) here, there are only three options: ocean_ice_bgc, ocean_ice, ocean_only 
clab='ocean_ice_bgc'; #only three options: ocean_ice_bgc, ocean_ice, ocean_only

kw_dm18='true'; # True or false to turn on kw_dm18 which should only work for global bgc
                # kw_dm18 uses Deike and Melville's (2018) formulation to compute dic_kw

EXENAME=$clab 
BASEDIR=$(pwd);
MKF_TEMPLATE="$BASEDIR/tigercpu-intel_optimized.mk"

#set the default branch in the begining compile
cd src/MOM6;       
cd ../SIS2;        
cd ../ocean_BGC;   
cd ../FMS1;        
cd ../coupler;     
cd ../atmos_null;
cd ../../

if $kw_dm18 && [[ "$clab" = *"ocean_ice_bgc"* ]]; then 
   EXENAME=$EXENAME"_kw_dm18" #
fi

echo "Compile FMS"
mkdir -p build/intel/shared/repro/
(cd build/intel/shared/repro/; rm -f path_names; \
"$BASEDIR/src/mkmf/bin/list_paths" -l "$BASEDIR/src/FMS"; \
"$BASEDIR/src/mkmf/bin/mkmf" -t $MKF_TEMPLATE -p libfms.a -c "-Duse_libMPI -Duse_netCDF -DSPMD -DMAXFIELDMETHODS_=400" path_names)

echo "Make NETCDF "
(cd build/intel/shared/repro/; source ../../env; make clean; make NETCDF=3 REPRO=1 libfms.a -j)

echo "List Model Code paths"
BUILDDIR="build/intel/$EXENAME/repro/"
mkdir -p $BUILDDIR

if [[ "$clab" = "ocean_only" ]]; then
   (cd $BUILDDIR; rm -f path_names; \
   "$BASEDIR/src/mkmf/bin/list_paths" -v -v -v ./ $BASEDIR/src/MOM6/config_src/{infra/FMS1,memory/dynamic_symmetric,drivers/solo_driver,external} $BASEDIR/src/MOM6/pkg/GSW-Fortran/{modules,scripts,toolbox} $BASEDIR/src/MOM6/src/{*,*/*}/)

   echo "Compile Model ocean_only and make executable file"
   (cd $BUILDDIR; \
   "$BASEDIR/src/mkmf/bin/mkmf" -t $MKF_TEMPLATE -o '-I../../shared/repro' -p $EXENAME -l '-L../../shared/repro -lfms' -c '-Duse_libMPI -Duse_netCDF -DSPMD -D_USE_MOM6_DIAG -DUSE_PRECISION=2' path_names )

elif [[ "$clab" = "ocean_ice" ]]; then
   # this is the default compile for ocean-ice model which is non-bio and non-symmetrical
   (cd $BUILDDIR; rm -f path_names; \
   "$BASEDIR/src/mkmf/bin/list_paths" -v -v -v ./ $BASEDIR/src/MOM6/config_src/{infra/FMS1,memory/dynamic_symmetric,drivers/FMS_cap,external} $BASEDIR/src/MOM6/pkg/GSW-Fortran/{modules,scripts,toolbox} $BASEDIR/src/MOM6/src/{*,*/*}/ $BASEDIR/src/{atmos_null,coupler,land_null,ice_param,icebergs,SIS2,FMS/coupler,FMS/include}/) 

   echo "Compile Model ocean_ice and make executable file"
   (cd $BUILDDIR; \
   "$BASEDIR/src/mkmf/bin/mkmf" -t $MKF_TEMPLATE -o '-I../../shared/repro' -p $EXENAME -l '-L../../shared/repro -lfms' -c '-Duse_libMPI -Duse_netCDF -DSPMD -Duse_AM3_physics -D_USE_LEGACY_LAND_ -D_USE_MOM6_DIAG -DUSE_PRECISION=2' path_names )

elif [[ "$clab" = *"ocean_ice_bgc"* ]]; then
   # compile MOM6-SIS2-COBALT bgc module
   #is there a reason why we are listing all the src/external paths separately here?? # prustogi_update: changed symmetric memory term
   (cd $BUILDDIR; rm -f path_names; \
   "$BASEDIR/src/mkmf/bin/list_paths" -v -v -v ./ $BASEDIR/src/MOM6/config_src/{infra/FMS1,memory/dynamic_symmetric,drivers/FMS_cap,external/ODA_hooks,external/drifters,external/stochastic_physics,external/database_comms} $BASEDIR/src/MOM6/pkg/GSW-Fortran/{modules,scripts,toolbox} $BASEDIR/src/MOM6/src/{*,*/*}/ $BASEDIR/src/{atmos_null,coupler,land_null,ice_param,icebergs,SIS2,FMS/coupler,FMS/include}/ $BASEDIR/src/ocean_BGC/{generic_tracers,mocsy/src})

   echo "Compile Model ocean_ice_bgc and make executable file"
   (cd $BUILDDIR; \
   "$BASEDIR/src/mkmf/bin/mkmf" -t $MKF_TEMPLATE -o '-I../../shared/repro' -p $EXENAME -l '-L../../shared/repro -lfms' -c '-Duse_libMPI -Duse_netCDF -DSPMD -Duse_AM3_physics -D_USE_LEGACY_LAND_ -D_USE_MOM6_DIAG -D_USE_GENERIC_TRACER -DUSE_PRECISION=2' path_names )
fi

(cd $BUILDDIR; source ../../env;make clean; make NETCDF=3 $EXENAME -j)





