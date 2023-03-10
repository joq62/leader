%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description :  1
%%% 
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(test_nodes).   
    
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------

%% External exports
-export([get_nodenames/0,
	 get_nodes/0,
	start_slave/1,
	 start_slave/2,
	start_nodes/0
	]). 


%% ====================================================================
%% External functions
%% ====================================================================


%% --------------------------------------------------------------------
%% Function:tes cases
%% Description: List of test cases 
%% Returns: non
%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
-define(NodeNames,["c1","c2","c3","c4"]).

get_nodenames()->
    ?NodeNames.    

get_nodes()->
    HostId=net_adm:localhost(),
    [list_to_atom(NodeName++"@"++HostId)||NodeName<-?NodeNames].
      
start_slave(NodeName)->
    HostId=net_adm:localhost(),
    Node=list_to_atom(NodeName++"@"++HostId),
    rpc:call(Node,init,stop,[]),
    Cookie=atom_to_list(erlang:get_cookie()),
    Args="-pa ebin -setcookie "++Cookie,
    slave:start(HostId,NodeName,Args).


start_slave(NodeName,Pargs)->
    HostId=net_adm:localhost(),
    Node=list_to_atom(NodeName++"@"++HostId),
    rpc:call(Node,init,stop,[]),
    Cookie=atom_to_list(erlang:get_cookie()),
    Args=Pargs++" "++"-setcookie "++Cookie,
    slave:start(HostId,NodeName,Args).
    
start_nodes()->

    [rpc:call(N,init,stop,[],1*1000)||N<-get_nodes()],
    timer:sleep(2000),
  
    [start_slave(NodeName)||NodeName<-?NodeNames],
   % gl=atom_to_list(erlang:get_cookie()), 
    [net_adm:ping(N)||N<-get_nodes()],
    ok.
