function FFT_NS_Solver()

%
% Solves the Navier-Stokes equations in the Vorticity-Stream Function
% formulation using a pseudo-spectral approach w/ FFT
%
% Author: Nicholas A. Battista
% Created: Novermber 29, 2014
% Modified: December 5, 2014
% 
% Equations of Motion:
% D (Vorticity) /Dt = nu*Laplacian(Vorticity)  
% Laplacian(Psi) = - Vorticity                                                       
%
%      Real Space Variables                   Fourier (Frequency) Space                                                          
%       SteamFunction: Psi                     StreamFunction: Psi_hat
% Velocity: u = Psi_y & v = -Psi_x              Velocity: u_hat ,v_hat
%         Vorticity: Vort                        Vorticity: Vort_hat
%
%
% IDEA: for each time-step
%       1. Solve Poisson problem for Psi (in Fourier space)
%       2. Compute nonlinear advection term by finding u and v in real
%          variables by doing an inverse-FFT, compute advection, transform
%          back to Fourier space
%       3. Time-step vort_hat in frequency space using a semi-implicit
%          Crank-Nicholson scheme (explicit for nonlinear adv. term, implicit
%          for viscous term)
%

% Print key fluid solver ideas to screen
print_FFT_NS_Info();

%
% Simulation Parameters
%
nu=1.0e-3;  % dynamic viscosity
NX = 256;   % # of grid points in x
NY = 256;   % # of grid points in y
LX = 1;     % 'Length' of x-Domain
LY = 1;     % 'Length' of y-Domain

%
% Choose initial vorticity state
% Choices:  'half', 'qtrs', 'rand' ,'bubble1', 'bubble2', 'bubbleSplit'
%
choice='bubble2';
[vort_hat,dt,tFinal,plot_dump] = please_Give_Initial_Vorticity_State(choice,NX,NY);

%
% Initialize wavenumber storage for fourier exponentials
%
[kMatx, kMaty, kLaplace] = please_Give_Wavenumber_Matrices(NX,NY);


t=0.0;            %Initialize time to 0.0
fprintf('Simulation Time: %d\n',t);
nTot = tFinal/dt; %Total number of time-steps
for n=0:nTot      %Enter Time-Stepping Loop!
    
    % Printing zero-th time-step
    if n==0
        
        %Solve Poisson Equation for Stream Function, psi
        psi_hat = please_Solve_Poission(vort_hat,kMatx,kMaty,NX,NY);

        %Find Velocity components via derivatives on the stream function, psi
        u  =real(ifft2( kMaty.*psi_hat));        % Compute  y derivative of stream function ==> u = psi_y
        v  =real(ifft2(-kMatx.*psi_hat));        % Compute -x derivative of stream function ==> v = -psi_x
        
        % SAVING DATA TO VTK %
        ctsave = 0;
        % CREATE VIZ_IB2D FOLDER and VISIT FILES
        mkdir('vtk_data');
            
        % Transform back to real space via Inverse-FFT
        vort_real=real(ifft2(vort_hat));

        % Save .vtk data!
        print_vtk_files(ctsave,u',v',vort_real',LX,LY,NX,NY);
   
    else
    
        %Solve Poisson Equation for Stream Function, psi
        psi_hat = please_Solve_Poission(vort_hat,kMatx,kMaty,NX,NY);

        %Find Velocity components via derivatives on the stream function, psi
        u  =real(ifft2( kMaty.*psi_hat));        % Compute  y derivative of stream function ==> u = psi_y
        v  =real(ifft2(-kMatx.*psi_hat));        % Compute -x derivative of stream function ==> v = -psi_x

        %Compute derivatives of voriticty to be "advection operated" on
        vort_X=real(ifft2( kMatx.*vort_hat  ));  % Compute  x derivative of vorticity
        vort_Y=real(ifft2( kMaty.*vort_hat  ));  % Compute  y derivative of vorticity

        %Compute nonlinear part of advection term
        advect = u.*vort_X + v.*vort_Y;          % Advection Operator on Vorticity: (u,v).grad(vorticity)   
        advect_hat = fft2(advect);               % Transform advection (nonlinear) term of material derivative to frequency space

        % Compute Solution at the next step (uses Crank-Nicholson Time-Stepping)
        vort_hat = please_Perform_Crank_Nicholson_Semi_Implict(dt,nu,NX,NY,kLaplace,advect_hat,vort_hat);
        %vort_hat = ((1/dt + 0.5*nu*kLaplace)./(1/dt - 0.5*nu*kLaplace)).*vort_hat - (1./(1/dt - 0.5*nu*kLaplace)).*advect_hat;

        % Update time
        t=t+dt; 

        % Plotting the vorticity field
    %     if mod(n,plot_dump) == 0
    %         
    %         % Transform back to real space via Inverse-FFT
    %         vort_real=real(ifft2(vort_hat));
    %         
    %         % Compute smaller matrices for velocity vector field plots
    %         newSize = 200;       %new desired size of vector field to plot (i.e., instead of 128x128, newSize x newSize for visual appeal)
    %         [u,v,xVals,yVals] = please_Give_Me_Smaller_Velocity_Field_Mats(u,v,NX,NY,newSize);
    %         
    %         contourf(vort_real,10); hold on;
    %         quiver(xVals(1:end),yVals(1:end),u,v); hold on;
    %         
    %         colormap('jet'); colorbar; 
    %         title(['Vorticity and Velocity Field at time ',num2str(t)]);
    %         axis([1 NX 1 NY]);
    %         drawnow;
    %         %pause(0.01);
    %         
    %     end

        % Save files info!
        ctsave = ctsave + 1;
        if mod(ctsave,plot_dump) == 0

            % Transform back to real space via Inverse-FFT
            vort_real=real(ifft2(vort_hat));

            % Save .vtk data!
            print_vtk_files(ctsave,u',v',vort_real',LX,LY,NX,NY);

            % Plot simulation time
            fprintf('Simulation Time: %d\n',t);

        end
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function to choose initial vorticity state
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function [vort_hat,dt,tFinal,plot_dump] = please_Give_Initial_Vorticity_State(choice,NX,NY)

if strcmp(choice,'half');
    
    vort=zeros(NX,NY);
    vort(1:NX/2,:)=1;
    dt=5e-2;        % time step
    tFinal = 1000;  % final time
    plot_dump=100;  % interval for plots

elseif strcmp(choice,'qtrs')
    
    vort = zeros(NX,NY);
    vort(1:NX/2,1:NY/2)=1;
    vort(NX/2+1:end,NY/2+1:end)=1;
    dt=1e-2;      % time step
    tFinal=2.5;   % final time
    plot_dump=5;  % interval for plots'
   
elseif strcmp(choice,'rand')
    
    vort = 2*rand(NX,NY)-1;
    dt=1e-1;       % time step
    tFinal = 1000; % final time
    plot_dump=25;  % interval for plots

elseif strcmp(choice,'bubble1')
    
    vort = 0.25*rand(NX,NY)-0.50;
    a=repmat(-NX/4+1:NX/4,[NY/2 1]);
    b1 = ( (a-1).^2 +  (a+1)'.^2 ) < 1024;
    b1 = double(b1);
    [r1,c1]=find(b1==1);
    b1 = 0.5*rand(NX/2,NY/2)-0.25;
    for i=1:length(r1)
        b1(r1(i),c1(i))=  0.5*(rand(1)+1);
    end
    vort(NX/4+1:3*NX/4,NY/4+1:3*NY/4) = b1;
    
    dt=5e-3;      % time step
    tFinal = 7.5;   % final time
    plot_dump=10; % interval for plots
    
elseif strcmp(choice,'bubbleSplit')
    
    vort = 0.5*rand(NX,NY)-0.25;
    a=repmat(-NX/4+1:NX/4,[NY/2 1]);
    b1 = ( (a-1).^2 +  (a+1)'.^2 ) < 1024;
    b1 = double(b1);
    [r1,c1]=find(b1==1);
    b1 = 0.5*rand(NX/2,NY/2)-0.25;
    for i=1:length(r1)
        if c1(i) < NX/4
            b1(r1(i),c1(i))=  0.10*(rand(1)-1.0);
        else
            b1(r1(i),c1(i))=  0.10*(rand(1)+0.90);
        end
    end
    vort(NX/4+1:3*NX/4,NY/4+1:3*NY/4) = b1;
    
    dt=5e-3;      % time step
    tFinal = 7.5; % final time
    plot_dump=10; % interval for plots
    
elseif strcmp(choice,'bubble2')
    
    %Initialize vort matrix
    vort = 2*rand(NX,NY)-1;

    ex = 2; %Makes sure full bubbles
    sL = 5; %shift left
    a1=repmat(-NX/4+(1-ex):NX/4,[NY/2+ex 1]);
    b1 = ( (a1-1).^2 +  (a1+1)'.^2 ) < NX*8+NX/1.5;
    b1 = double(b1);
    nZ = find(b1);
    b1(nZ) = 0.8; 
    [r1,c1]=find(b1==0);
    for i=1:length(r1)
        b1(r1(i),c1(i))=  2*rand(1)-1;
    end
    vort(NX/4+(1-ex):3*NX/4,NY/4+(1-ex)-sL:3*NY/4-sL) = b1;

    
    a2=repmat(-NX/8+(1-ex):NX/8,[NY/4+ex 1]);
    b2 = ( (a2-1).^2 +  (a2+1)'.^2 ) < 2*NX+NX/0.75;
    b2 = double(b2);
    nZ = find(b2);
    b2(nZ) = -1.0; 
    [r2,c2]=find(b2==0);
    for i=1:length(r2)
        b2(r2(i),c2(i))=  1.0; 
    end
    vort(3*NX/8+(1-ex):5*NX/8,3*NY/8+(1-ex):5*NY/8) = b2;
   
    sR = 4; %shift right / down
    a3=repmat(-NX/16+(1-ex):NX/16,[NY/8+ex 1]);
    b3 = ( (a3-1).^2 +  (a3+1)'.^2 ) < NX/2;
    b3 = double(b3);
    nZ=find(b3);
    b3(nZ)= 1.0; 
    [r3,c3]=find(b3==0);
    for j=1:length(r3)
        b3(r3(j),c3(j)) =  -1.0; 
    end
    vort(7*NX/16+(1-ex)-sR:9*NX/16-sR,7*NY/16+(1-ex)+sR:9*NY/16+sR) = b3;
    
    dt = 1e-2;      % time step
    tFinal = 30;    % final time
    plot_dump= 50;  % interval for plots
    
end

% Finally transform initial vorticity state to frequency space using FFT
vort_hat=fft2(vort);  

% Print simulation information
print_Simulation_Info(choice);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [kMatx, kMaty, kLaplace] = please_Give_Wavenumber_Matrices(NX,NY)

kMatx = zeros(NX,NY);
kMaty = kMatx;

rowVec = [0:NX/2 (-NX/2+1):1:-1];
colVec = [0:NY/2 (-NY/2+1):1:-1]';

%Makes wavenumber matrix in x
for i=1:NY
   kMatx(i,:) = 1i*rowVec;
end

%Makes wavenumber matrix in y (NOTE: if Nx=Ny, kMatx = kMaty')
for j=1:NX
   kMaty(:,j) = 1i*colVec; 
end

% Laplacian in Fourier space
kLaplace=kMatx.^2+kMaty.^2;        

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function to solve poisson problem, Laplacian(psi) = -Vorticity
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function psi_hat = please_Solve_Poission(w_hat,kx,ky,NX,NY)

psi_hat = zeros(NX,NY); %Initialize solution matrix
kVecX = kx(1,:);        %Gives row vector from kx
kVecY = ky(:,1);        %Gives column vector from ky

for i = 1:NX
    for j = 1:NY
        if ( i+j > 2 )
            psi_hat(i,j) = -w_hat(i,j)/( ( kVecX(i)^2+ kVecY(j)^2 ) ); % "inversion step"
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function to take every few entries from velocity field matrices for
% plotting the field. (For aesthetic purposes)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [u,v,xVals,yVals] = please_Give_Me_Smaller_Velocity_Field_Mats(uOld,vOld,NX,NY,newSize)

iterX = NX/newSize;
xVals = 1:iterX:NX;

iterY = NY/newSize;
yVals = 1:iterY:NY;

if ( mod(NX,newSize) > 0 ) || ( mod(NY,newSize) > 0 )
    
    %If numbers don't divide properly throw this flag and use original
    fprintf('Will not be able to reSize velocity field matrices.');
    xVals = 1:NX;
    yVals = 1:NY;
    u = uOld;
    v = vOld;
    
else
    
    u = zeros(length(xVals),length(yVals));  %initialize new u
    v = u;                                   %initialize new v
    n = 0; m = 0;                            %initializing new counter for resizing
    for i=1:NX
        if mod(i,iterX)==1
            n = n+1;
            for j=1:NY
                if ( mod(j,iterY) == 1 )
                    m = m+1;
                    u(n,m) = uOld(i,j);
                    v(n,m) = vOld(i,j);
                end
            end
            m=0;
        end
    end
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function to perform one time-step of Crank-Nicholson Semi-Implicit
% timestepping routine to get next time-step's vorticity coefficients in
% fourier (frequency space). 
%
% Note: 1. The nonlinear advection is handled explicitly
%       2. The viscous term is handled implictly
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function vort_hat = please_Perform_Crank_Nicholson_Semi_Implict(dt,nu,NX,NY,kLaplace,advect_hat,vort_hat)

    for i=1:NX
        for j=1:NY

            %Crank-Nicholson Semi-Implicit Time-step
            vort_hat(i,j) = ( (1 + dt/2*nu*kLaplace(i,j) )*vort_hat(i,j) - dt*advect_hat(i,j) ) / (  1 - dt/2*nu*kLaplace(i,j) );

        end
    end
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function to print information about fluid solver
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_FFT_NS_Info()

fprintf('\n_________________________________________________________________________\n\n');
fprintf(' \nSolves the Navier-Stokes equations in the Vorticity-Stream Function \n');
fprintf(' formulation using a pseudo-spectral approach w/ FFT \n\n');
fprintf(' Author: Nicholas A. Battista \n');
fprintf(' Created: Novermber 29, 2014 \n');
fprintf(' Modified: December 5, 2014 \n\n');
fprintf(' Equations of Motion: \n');
fprintf(' D (Vorticity) /Dt = nu*Laplacian(Vorticity)  \n');
fprintf(' Laplacian(Psi) = - Vorticity                 \n\n');                                     
fprintf('      Real Space Variables                   Fourier (Frequency) Space              \n');                                            
fprintf('       SteamFunction: Psi                     StreamFunction: Psi_hat \n');
fprintf(' Velocity: u = Psi_y & v = -Psi_x              Velocity: u_hat ,v_hat \n');
fprintf('         Vorticity: Vort                        Vorticity: Vort_hat \n\n');
fprintf('_________________________________________________________________________\n\n');
fprintf(' IDEA: for each time-step \n');
fprintf('       1. Solve Poisson problem for Psi (in Fourier space)\n');
fprintf('       2. Compute nonlinear advection term by finding u and v in real \n');
fprintf('          variables by doing an inverse-FFT, compute advection, transform \n');
fprintf('          back to Fourier space \n');
fprintf('       3. Time-step vort_hat in frequency space using a semi-implicit \n');
fprintf('          Crank-Nicholson scheme (explicit for nonlinear adv. term, implicit \n');
fprintf('          for viscous term) \n');
fprintf('_________________________________________________________________________\n\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function to print information about specific simulation
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_Simulation_Info(choice)

if strcmp(choice,'bubble1')
   
    fprintf('You are simulating one dense region of CW vorticity in a bed of random vorticity values\n');
    fprintf('Try changing the dynamic viscosity to see how flow changes\n');
    fprintf('_________________________________________________________________________\n\n');

    
elseif strcmp(choice,'bubble2')
    
    fprintf('You are simulating three nested regions of Vorticity (CW,CCW,CW) in a bed of random vorticity values\n');
    fprintf('Try changing the position of the nested vortices in the "please_Give_Initial_State" function\n');
    fprintf('Try changing the dynamic viscosity to see how flow changes\n');
    fprintf('_________________________________________________________________________\n\n');


elseif strcmp(choice,'bubbleSplit')
    
    fprintf('You are simulating two vortices which are very close\n');
    fprintf('Try changing the initial vorticity distribution on the left or right side\n');
    fprintf('Try changing the dynamic viscosity to see how the flow changes\n');
    fprintf('_________________________________________________________________________\n\n');

    
elseif strcmp(choice,'qtrs')
    
    fprintf('You are simulating 4 squares of differing vorticity\n');
    fprintf('Try changing the dynamic viscosity to see how the flow changes\n');
    fprintf('_________________________________________________________________________\n\n');

    
elseif strcmp(choice,'half')
    
    fprintf('You are simulating two half planes w/ opposite sign vorticity\n');
    fprintf('Try changing the dynamic viscosity to see how the flow changes\n');
    fprintf('_________________________________________________________________________\n\n');


elseif strcmp(choice,'rand')
   
    fprintf('You are simulating a field of random vorticity values\n');
    fprintf('Try changing the dynamic viscosity to see how the flow changes\n');
    fprintf('_________________________________________________________________________\n\n');

     
end