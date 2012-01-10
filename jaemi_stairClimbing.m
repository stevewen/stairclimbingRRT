%% Stair climbing using CBiRRT

% Set up environment
clear all;
close all;

%TODO encapsulate the below functions into a single matlab routine:
%   1) set initial DOF values
%   2) define goal transform
%   3) define Bw for solution

%load the environment
orEnvLoadScene('openHubo/jaemiHubo.stairClimbing.env.xml',1);

%TODO create box model of foot base with appropriate coordinate system, so that
%bottom center of the foot can be used as the center of a manipulator
%TODO define foot goal on first step
T0_footGoal = MakeTransform(eye(3),[.0 .15 .095 ]');

%footDummyid = orEnvCreateKinBody('rightfoot','openHubo/rightFoot.dummy.kinbody.xml');
%orBodySetTransform(footDummyid, [GetRot(T0_footGoal) GetTrans(T0_footGoal)]');

robotid = orEnvGetBody('jaemiHubo');

%set printing and display options
orEnvSetOptions('debug 5')
orEnvSetOptions('collision ode')

disp('Initial setup done');
%create problem instances 
probs.cbirrt = orEnvCreateProblem('CBiRRT','jaemiHubo');

%get the descriptions of the robot's manipulators
manips = orRobotGetManipulators(robotid);

activedofs = [manips{3}.armjoints];

% start the robot in a reasonable location and configuration
disp('Set Initial transform');
%TODO Set initial pose 
initDOFValues=[.1 .1 .5 1 .5 .1]; 
orRobotSetDOFValues(robotid,initDOFValues,[manips{3}.armjoints]);

%set the active dof
orRobotSetActiveDOFs(robotid,activedofs);

% First TSR: the goal for the foot.

%place the first TSR's reference frame at the object's frame relative to world frame
T0_w = T0_footGoal;

%Coincident for now...
Tw_e1 = T0_w; 

% Foot landing bounds: TODO
%   1) restricted Z height to actually land
%   2) Reasonable Y movement for flexibility
%   3) Restrict X movement to lie on step (hand-tuned for now)
Bw = [-.1 .1  -.1 .1   -.1 .1   -.1 .1   -.1 .1  -.1 .1]  ;

TSRstring1 = SerializeTSR(0,'NULL',T0_w,Tw_e1,Bw);
TSRChainString1 = SerializeTSRChain(0,1,0,1,TSRstring1,'NULL',[]);

%call the cbirrt planner, it will generate a file with the trajectory called 'cmovetraj.txt'
orProblemSendCommand(['RunCBiRRT psample 0.05 ' TSRChainString1],probs.cbirrt);

%execute the trajectories generated by the planner, run the webots model side-by-side
%%TODO rename this goal trajectory
orProblemSendCommand(['traj cmovetraj.txt'],probs.cbirrt);
orEnvWait(1);

%TODO: Gut this section:
%   1) Plot resulting trajectories
%   2) Eventually send this to ACES via the hubo transport

%%% PLot the resulting trajectory, and export it to a format ACES can use
%% 1) load the trajectory
rawData=importdata('cmovetraj.txt',' ',3);
%
%%Column order is, as best I can tell based on the initial pose:
%% t RSP RSR RSY REP RWY RWR RWP <Robot overall rotation quaternion, 4> <Robot overall translation vector, 3>
graspTestTraj=rawData.data(:,2:8);
dt=mean(diff(rawData.data(:,1)));
