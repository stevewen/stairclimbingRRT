%load the robot into the environment
orEnvLoadScene('openHubo/jaemiHubo.robot.xml',1);
robotid = orEnvGetBody('jaemiHubo');

%set printing and display options
orEnvSetOptions('debug 2')
orEnvSetOptions('collision ode')

manips = orRobotGetManipulators(robotid);

activeManip=3;

fprintf('Working with Manipulator #%d',activeManip);

activedofs = [manips{activeManip+1}.armjoints];
orRobotSetActiveDOFs(robotid,activedofs);

objectid = orEnvCreateKinBody('footPlate','openHubo/footPlate.kinbody.xml');

%create the problem instance
probs.cbirrt = orEnvCreateProblem('CBiRRT','jaemiHubo');

%get the descriptions of the robot's manipulators
manips = orRobotGetManipulators(robotid);

%Set Arms to non-colliding pose
orRobotSetDOFValues(robotid,[0 pi/3 0 0 0 0 0],manips{1}.armjoints);
orRobotSetDOFValues(robotid,[0 -pi/3 0 0 0 0 0],manips{2}.armjoints);

%set initial configuration
initRightLeg = [0 0 -.1 .2 -.1 0];
initLeftLeg = [0 0 0 -.1 .2 -.1 0];

T_away=[eye(3),[0;0;2];0 0 0 1];

for k=1:50
    %Prepare for a new iteration:
    orRobotSetDOFValues(robotid,initRightLeg,activedofs);

    %Find a collision-free goal position
    goalInCollision=1;
    while(goalInCollision==1)
        r=rand()*pi/6-pi/12;
        p=rand()*pi/6-pi/12;
        y=rand()*pi/8-pi/16;
        R_t=Rz(y)*Rx(r)*Ry(p)
        t=rand(3,1).*[.5;.5;.2] - [.2 .3 .95]';

        T0_w=[R_t,t;0 0 0 1];
        Tw_e1=[eye(3),[0;0;.008];0 0 0 1];

        orBodySetTransform(objectid, [GetRot(T0_w) GetTrans(T0_w)]');
        pause(.05)
        goalInCollision = orEnvCheckCollision(robotid)
    end
    disp('Found Collision-Free goal')
    pause(.5)
        orBodySetTransform(objectid, [GetRot(T_away) GetTrans(T_away)]');

    orRobotSetDOFValues(robotid,initRightLeg,activedofs);
    %Allow a large range of rotations to reach the goal, just to see if the planner can do this
    Bw = [-.005 .005 -.005 .005 -0.005 0.005 -.01 .01 -.01 .01 -.01 .01 ];
    TSRstring1 = SerializeTSR(activeManip,'NULL',T0_w,Tw_e1,Bw);
    TSRChainString1 = SerializeTSRChain(0,1,0,1,TSRstring1,'NULL',[]);

    %call the cbirrt planner, it will generate a file with the trajectory called 'cmovetraj.txt'
    soln=orProblemSendCommand(['RunCBiRRT psample 0.20 timelimit 30 smoothingitrs 20' TSRChainString1],probs.cbirrt)
    if strcmp(soln,'1')
        processTraj('cmovetraj.txt',.01)
        %execute the trajectories generated by the planner
        orProblemSendCommand(['traj new-cmovetraj.txt'],probs.cbirrt);
        orEnvWait(.1);
        pause(3)
    end
end
