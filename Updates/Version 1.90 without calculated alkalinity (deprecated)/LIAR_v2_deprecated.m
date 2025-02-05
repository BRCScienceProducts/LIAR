function [AlkalinityEstimates,UncertaintyEstimates]=LIAR_v2(Coordinates,Measurements,MeasIDVec,Equations,MeasUncerts,MolalityTF)
%  Locally Interpolated Alkalinity Regression (LIAR): Estimates alkalinity
%  and alkalinity uncertainty from combinations of other parameter
%  measurements.
% 
%  This function needs the CSIRO seawater package to run if measurements
%  are povided in molar units, or if potential temperature or AOU are
%  needed but not provided by the user.  Scale differences from TEOS-10 are
%  a negligible component of alkalintiy estimate error.  The seawater
%  package is distributed freely by CSIRO:
% 
%  http://www.cmar.csiro.au/datacentre/ext_docs/seawater.htm
% 
% *************************************************************************
% Input/Output dimensions:
% n: Integer number of desired estimate locations
% e: Integer number of equations used at each location
% y: Integer number of parameter measurement types provided by the user.
% n*e: Total number of estimates returned
% 
% *************************************************************************
% Input descriptions:
% 
% Coordinates (required n by 3 array): Coordinates at which estimates are
% desired.  The first column should be longitude (degrees E), the second
% column should be latitude (degrees N), and the last column should be
% depth (m).  NaN coordinate values will return NaN estimates.
% 
% 
% Measurements (required n by y array): Parameter measurements that will be
% used to estimate alkalinity.  The column order is arbitrary, but
% specified by MeasIDVec.  Concentrations (including AOU) should be
% expressed as micromol per kg unless MolalityTF is set to 0, temperature
% should be expressed as degrees C, and salinity should be specified with
% the unitless convention.  NaN inputs are acceptable, but will lead to NaN
% estimates for any equations that depend on that parameter.
% 
% 
% MeasIDVec (required 1 by y vector): Vector indicating which parameter is
% placed in each column of the 'Measurements' input.  Note that salinity is
% required for all equations.  If O2 is provided instead of AOU, then
% temperature or potential temperature must also be provided to convert O2
% to AOU.  For example, if the first three columns of 'Measurements'
% contain salinity, silicate, and temperature, then MeasIDVec should equal
% [1 4 7].
% 
% Parameter Key: 
% 1. Salinity
% 2. Potential temperature 
% 3. Nitrate
% 4. AOU
% 5. Silicate
% 6. O2
% 7. Temperature
% 
% 
% Equations (optional 1 by e vector, default 1:16): Vector indicating which
% equations will be used to estimate alkalinity. This input also determines
% the order of the columns in the 'AlkalinityEstimates' output.
% 
% (S=salinity, Theta=potential temperature, N=nitrate, Si=silicate,
% AOU=apparent oxygen utilization... see 'Measurements' for units).
% 
% Equation Key: 
% 1.  S, Theta, N, AOU, Si
% 2.  S, Theta, N, Si
% 3.  S, Theta, AOU, Si
% 4.  S, Theta, Si
% 5.  S, Theta, N, AOU
% 6.  S, Theta, N
% 7.  S, Theta, AOU
% 8.  S, Theta
% 9.  S, N, AOU, Si
% 10. S, N, Si
% 11. S, AOU, Si
% 12. S, Si
% 13. S, N, AOU
% 14. S, N
% 15. S, AOU
% 16. S
% 
% 
% MeasUncerts (Optional n by y array or 1 by y vector, default 1 by y
% vector of uncertainties specified in paper): Array of measurement
% uncertainties (see 'Measurements' for units). Uncertainties should be
% presented in order indicated by MeasIDVec. Providing these estimates will
% improve LIAR estimate uncertainties in 'UncertaintyEstimates'.
% Measurement uncertainties are a small part of LIAR estimate uncertainties
% for WOCE-quality measurements.  However, estimate uncertainty scales with
% measurement uncertainty, so it is recommended that measurement
% uncertainties be specified for sensor measurements.  If this optional
% input argument is not provided, the default WOCE-quality uncertainty is
% assumed.  If a 1 by y array is provided then the uncertainty estimates
% are assumed to apply uniformly to all input parameter measurements.  If
% default values are desired but you want to specify MolalityTF, then
% input [].
% 
% 
% MolalityTF (Optional boolean, default true): Many sensors provide
% measurements in micromol per L (molarity) instead of micromol per kg
% (molality). Indicate false or 0 if provided measurements are expressed in
% molar units (concentrations must be micromol per L if so).
% 
% 
% *************************************************************************
% Output descriptions:
%  
% 
% AlkalinityEstimates: A n by e array of LIAR estimates specific to
% the coordinates and parameter measurements provided.  Units are micromols
% of total seawater titration alkalinity per kg of seawater regardless of
% whether MolalityTF is 0 or 1.
% 
% 
% UncertaintyEstimates: A n by e array of LIAR uncertainty estimates
% specific to the coordinates, parameter measurements, and parameter
% uncertainties provided.  Units are standard deviations of total seawater
% titration alkalinity in micromoles per kg of seawater regardless of
% whether MolalityTF is true or false.
% 
% *************************************************************************
% Missing data: should be indicated with a NaN.  A NaN coordinate will yield
% NaN estimates for all equations at that coordinate.  A NaN parameter
% value will yield NaN estimates for all equations that require that
% parameter.
% 
% *************************************************************************
tic

% Checking input arguments against expectations and setting default values
if nargin<3; error('LIAR called with too few input arguments.'); end
if nargin<6; MolalityTF=1; end
if nargin<5 || max(size(MeasUncerts))==0;
    MeasUncerts=[0.002 0.002 0.2 2 0.2 2 0.002]; 
    MeasUncerts=MeasUncerts(1,MeasIDVec);
    MeasUncerts=ones(size(Measurements(:,1)))*MeasUncerts;
end
if nargin<4; Equations=1:16; end
if ~(size(MeasIDVec,2)==size(Measurements,2));
    error('The MeasIDVec input does not have the same number of columns as the Measurements input.  This means it is unclear which measurement is in which column.');
end
if not(max(size(MeasUncerts)==size(Measurements))) && not(min(size(MeasUncerts)==size(Measurements))) && not(max(size(MeasUncerts))==0);
    error('MeasUncerts must be undefined, a vector with the same number of elements as Measurements has columns, [] (for default values), or an array of identical dimension to Measurements.')
elseif not(min(size(MeasUncerts)==size(Measurements))) && not(max(size(MeasUncerts))==0);
    MeasUncerts=ones(size(Measurements(:,1)))*MeasUncerts;
end

% Making sure you downloaded the file you needed and put it somewhere it
% can be found
if exist('LIAR_files_v2.mat','file')<2; error('LIAR could not find the LIAR_files file needed to run.  This mandatory file should be distributed from the same website as LIAR.  Contact the corresponding author if you cannot find it there.  If you do have it then make sure it is on the MATLAB path or in the active directory.'); end

% LIAR requires non-NaN coordinates to provide an estimate.  This step
% eliminates NaN coordinate combinations prior to estimation.  NaN
% estimates will be returned for these coordinates.
NaNCoords=max(isnan(Coordinates),[],2);
[NumCoords,~]=size(Coordinates);
n=sum(~NaNCoords);
[~,e]=size(Equations);


% Checking for common missing data indicator flags
if max(ismember([-999 -9 -1*10^20],Measurements))==1
    warning('LIAR warning: A common non-NaN missing data indicator (e.g. -999) was detected in the input measurements provided.  Missing data should be replaced with NaNs.  Otherwise, LIAR will interpret your inputs as given and give terrible estimates.')
end

% Checking to make sure all required parameters are provided
VarVec=[1 1 1 1 1
    1 1 1 0 1
    1 1 0 1 1
    1 1 0 0 1
    1 1 1 1 0
    1 1 1 0 0
    1 1 0 1 0
    1 1 0 0 0
    1 0 1 1 1
    1 0 1 0 1
    1 0 0 1 1
    1 0 0 0 1
    1 0 1 1 0
    1 0 1 0 0
    1 0 0 1 0
    1 0 0 0 0];
NeedVars=any(VarVec(Equations,:),1);
HaveVars=false(1,6);  HaveVars(1,MeasIDVec)=1; 

%Temperature can sub for potential temperature
if ismember(7,MeasIDVec)==1; HaveVars(1,2)=true; end

% Temperature or potential temperature is required if O2 is provided and
% AOU is not (unless AOU is not used).
if ismember(6,MeasIDVec)==1 && ismember(4,MeasIDVec)==0; NeedVars(1,2)=true; end

% If oxygen and temperature or potential temperature are present, then AOU is also present
if ismember(6,MeasIDVec)==1 && or(ismember(7,MeasIDVec)==1,ismember(2,MeasIDVec)==1);
    HaveVars(1,4)=true; 
end

% Temperature or potential temperature is required if
% measurements are provided in molar units
if MolalityTF==0; NeedVars(1,2)=1; end 

% Making sure all needed variables are present
if ~all(HaveVars(1,NeedVars))
    error('LIAR error: Check "Equations" and "MeasIDVec" inputs.  One or more regression equations selected require one or more input parameters that are either not provided or not labeled correctly.')
end


% Putting measurement inputs in expected order
M=NaN(n,7);  % Measurements
U=NaN(n,7);  % Uncertainties
M(:,MeasIDVec)=Measurements(~NaNCoords,:);
C=Coordinates(~NaNCoords,:);
U(:,MeasIDVec)=MeasUncerts(~NaNCoords,:);



% Checking to see whether potential temperature is defined and needed.
% Defining it and subbing in temp uncert for theta uncert if necessary.
if ismember(2,MeasIDVec)==0 && NeedVars(1,2);
    M(:,2)=sw_ptmp(M(:,1),M(:,7),sw_pres(C(:,3),C(:,2)),0);
    U(:,2)=U(:,7);
end
% Checking to see whether AOU is defined and needed. Defining it and
% subbing in O2 uncert for AOU uncert if necessary.
if ismember(4,MeasIDVec)==0 && NeedVars(1,4);
    M(:,4)=sw_satO2(M(:,1),M(:,2))*44.64-M(:,6);
    U(:,4)=U(:,6);
end
% Converting units to molality if they are provided as molarity.
if MolalityTF==0;
    densities=sw_dens(M(:,1),sw_temp(M(:,1),M(:,2), ...
        sw_pres(C(:,3),C(:,2)),0),sw_pres(C(:,3),C(:,2)))/1000;
    M(:,3)=M(:,3)./densities;
    M(:,4)=M(:,4)./densities;
    M(:,5)=M(:,5)./densities;
end

L=load('LIAR_files_v2.mat');
% Adjusting bizarre longitudes.
C(C(:,1)>360,1)=rem(C(C(:,1)>360,1),360);
C(C(:,1)<0,1)=rem(C(C(:,1)<0,1,1),360)+360;

% We don't want constants to be interpolated across the panama canal (for
% instance), so data is carved into two segments... the Atlantic/Arctic
% (AA) and everything else.  These interpolations are then done separately.
DepthToDegreeConversion=25;
C(:,3)=C(:,3)/DepthToDegreeConversion;
L.Coords(:,3)=L.Coords(:,3)/DepthToDegreeConversion; 
AAIndsM=or(inpolygon(C(:,1),C(:,2),L.LNAPoly(:,1),L.LNAPoly(:,2)), ...
    or(inpolygon(C(:,1),C(:,2),L.LSAPoly(:,1),L.LSAPoly(:,2)), ...
    or(inpolygon(C(:,1),C(:,2),L.LNAPolyExtra(:,1),L.LNAPolyExtra(:,2)), ...
    or(inpolygon(C(:,1),C(:,2),L.LSAPolyExtra(:,1),L.LSAPolyExtra(:,2)), ...
    inpolygon(C(:,1),C(:,2),L.LNOPoly(:,1),L.LNOPoly(:,2))))));

% Here we predefine a dummy interpolant.  We fill it with the actual values
% later, but this is the slow step, so we don't want it being done in a
% loop.  The appended "Dummy" values are designed to return the
% interpolated value at the nearest location within the domain when the
% desired estimate is outside of the domain.  Note that this is distinct
% from the scatteredInterpolant 'nearest' extrapolation option, which
% simply selectes the nearest neighbor of the input data points, and
% therefore results in discontinuities.  Dummy points accomplish this by
% interpolating between the values within the dataset and the mean value
% within the dataset 'placed' nearly infinitely far away.  Think of the 8
% dummy coordinates as the vertices of a very large cube around the data of
% interest.
Dummy=ones(8,1)*nanmean(nanmean(L.Cs,1),3);
Dummyset=horzcat([10^10; 10^10;10^10; 10^10;-10^10; -10^10;-10^10; ...
    -10^10],[10^10;-10^10;10^10;-10^10;10^10;-10^10;10^10;-10^10], ...
    [10^10;10^10;-10^10;-10^10;10^10;10^10;-10^10;-10^10]);
Dummy=horzcat(Dummyset,Dummy);

% Disambiguation:
% L.Cs (loaded from file)... pre-determined regression constants
% L.Coords (loaded from file)... coordinates of L.Cs
% C... viable subset of user-provided coordinates for LIAR estimates
% LCs... locally-interpolated L.Cs
InterpolantAA=scatteredInterpolant(vertcat(L.Coords(L.AAIndsCs,1), ...
    Dummyset(:,1)),vertcat(L.Coords(L.AAIndsCs,2),Dummyset(:,2)), ...
    vertcat(L.Coords(L.AAIndsCs,3),Dummyset(:,3)), ...
    (1:size(vertcat(L.Coords(L.AAIndsCs,3),Dummyset(:,3))))');
InterpolantElse=scatteredInterpolant(vertcat(L.Coords(~L.AAIndsCs,1), ...
    Dummyset(:,1)),vertcat(L.Coords(~L.AAIndsCs,2),Dummyset(:,2)), ...
    vertcat(L.Coords(~L.AAIndsCs,3),Dummyset(:,3)), ...
    (1:size(vertcat(L.Coords(~L.AAIndsCs,3),Dummyset(:,3))))');

%Preallocating for speed
AlkalinityEstimates=NaN(NumCoords,e);
UncertaintyEstimates=NaN(NumCoords,e);
AlkEst=NaN(n,e);
UncertEst=NaN(n,e);

% Disambiguation:
% Eq... a counter for which equation LIAR is on
% e... the number of equations that will be used
% Equation... the specific equation number currently being used
% Equations... the user provided list of equations that will be used.
for Eq=1:e;
    Equation=Equations(1,Eq);
    clear LCs    
%     selecting variables for this regression
    if Equation==1
        VarList='S Theta N AOU Si';
    elseif Equation==2
        VarList='S Theta N Si';
    elseif Equation==3
        VarList='S Theta AOU Si';
    elseif Equation==4
        VarList='S Theta Si';
    elseif Equation==5
        VarList='S Theta N AOU';
    elseif Equation==6
        VarList='S Theta N';
    elseif Equation==7
        VarList='S Theta AOU';
    elseif Equation==8
        VarList='S Theta';
    elseif Equation==9
        VarList='S N AOU Si';
    elseif Equation==10
        VarList='S N Si';
    elseif Equation==11
        VarList='S AOU Si';
    elseif Equation==12
        VarList='S Si';
    elseif Equation==13
        VarList='S N AOU';
    elseif Equation==14
        VarList='S N';
    elseif Equation==15
        VarList='S AOU';
    elseif Equation==16
        VarList='S';
    end
    UseVars=[1:5].*VarVec(Equation,:);
    UseVars(UseVars==0)=[];
%     Printing update on progress.  You may safely comment out this segment
%     if you dislike clutter.
    disp(horzcat(num2str(floor(toc)),' seconds elapsed... now using eqn. ', ...
        num2str(Equation),': ',VarList,'.'))
    
%     Determining dimensions
    SizUseVars=size(UseVars);
    LCs=NaN(n,SizUseVars(1,2));
    NumVars=1+SizUseVars(1,2);
    VarNumVec=horzcat(1,UseVars+1);
%     Filling the interpolants with the predetermined regression constant
%     information and then using them to interpret 'local constants' (LCs)
%     at the coordinates of interest.
    for Var=1:NumVars;
        InterpolantAA.Values=vertcat(L.Cs(L.AAIndsCs,VarNumVec(1,Var), ...
            Equation),Dummy(:,VarNumVec(Var)+3));
        InterpolantElse.Values=vertcat(L.Cs(~L.AAIndsCs,VarNumVec(1,Var), ...
            Equation),Dummy(:,VarNumVec(Var)+3));
        LCs(AAIndsM,Var)=InterpolantAA(C(AAIndsM,1),C(AAIndsM,2), ...
            C(AAIndsM,3));
        LCs(~AAIndsM,Var)=InterpolantElse(C(~AAIndsM,1), ...
            C(~AAIndsM,2),C(~AAIndsM,3));
    end
    % Estimating methodological error from salinity
    EMLR=interp1(L.EMLRrec(:,1),L.EMLRrec(:,1+Equation),M(:,1));
%     Estimating alkalnity and alkalinity estimate uncertainty from LCs.
    AlkEst(:,Eq)=real(sum(LCs.*horzcat(ones(n,1),M(:,UseVars)),2));
    UncertEst(:,Eq)=real((sum((LCs.*horzcat(zeros(n,1), ...
        U(:,UseVars))).^2,2)+3.3^2+EMLR.^2).^(1/2));
end
% Filling the outputs with the estimates at viable locations.
AlkalinityEstimates(~NaNCoords,:)=AlkEst;
UncertaintyEstimates(~NaNCoords,:)=UncertEst;
end
