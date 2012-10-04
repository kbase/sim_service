a module for sequence similiarity service


Dependencies
 - kb_seed
 - typecomp


To Deploy (last tested on kbase image v15):

 - launch new image
 - login as ubuntu
 - use the following commands
     sudo su
     cd /kb 
     git clone ssh://kbase@git.kbase.us/dev_container
     cd /kb/dev_container/modules
     git clone ssh://kbase@git.kbase.us/sim_service
     git clone ssh://kbase@git.kbase.us/typecomp
     git clone ssh://kbase@git.kbase.us/kb_seed
     cd /kb/dev_container
     ./bootstrap /kb/runtime
     source user-env.sh
     make deploy
 
  - start and stop the service by using scripts in /kb/deployment/services/sim_service
  - by default, this service deploys to port 7055
     


