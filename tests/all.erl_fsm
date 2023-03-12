%%% -------------------------------------------------------------------
%%% @author  : Joq Erlang
%%% @doc: : 
%%% Created :
%%% Node end point  
%%% Creates and deletes Pods
%%% 
%%% API-kube: Interface 
%%% Pod consits beams from all services, app and app and sup erl.
%%% The setup of envs is
%%% -------------------------------------------------------------------
-module(all).      
    
 
-export([start/1

	]).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

start([_ClusterSpec,_HostSpec])->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    
    ok=setup(),
    ok=test_1(),
   
    io:format("Stop OK !!! ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    timer:sleep(2000),
  % init:stop(),
    ok.


%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
test_1()->
  io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE}]),
    AllNodes=test_nodes:get_nodes(),
    [N1,N2,N3,N4]=AllNodes,
    %% Init
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE}]),
    []=[N||N<-AllNodes,
	   ok/=rpc:call(N,application,load,[leader],5000)],
    []=[N||N<-AllNodes,
	   ok/=rpc:call(N,application,set_env,[[{leader,[{nodes,AllNodes}]}]],5000)],
    
    %% N1
    ok=rpc:call(N1,application,start,[leader],5000),
    pong=rpc:call(N1,leader,ping,[],5000),
    timer:sleep(1000),
    N1=rpc:call(N1,leader,who_is_leader,[]),
    false=rpc:call(N1,leader,am_i_leader,[node()],5000),
    true=rpc:call(N1,leader,am_i_leader,[N1],5000),
    io:format("N1 leader OK! ~p~n",[{?MODULE,?LINE}]),

    %% N2
    ok=rpc:call(N2,application,start,[leader],5000),
    pong=rpc:call(N2,leader,ping,[],5000),
    timer:sleep(1000),
    N2=rpc:call(N2,leader,who_is_leader,[]),
    false=rpc:call(N1,leader,am_i_leader,[node()],5000),
    false=rpc:call(N1,leader,am_i_leader,[N1],5000),
    true=rpc:call(N1,leader,am_i_leader,[N2],5000),
    io:format("N2 leader OK! ~p~n",[{?MODULE,?LINE}]),

    %% N3
    ok=rpc:call(N3,application,start,[leader],5000),
    pong=rpc:call(N3,leader,ping,[],5000),
    timer:sleep(1000),
    N3=rpc:call(N1,leader,who_is_leader,[]),
    false=rpc:call(N1,leader,am_i_leader,[node()],5000),
    false=rpc:call(N1,leader,am_i_leader,[N1],5000),
    false=rpc:call(N3,leader,am_i_leader,[N2],5000),
    true=rpc:call(N1,leader,am_i_leader,[N3],5000),
    io:format("N3 leader OK! ~p~n",[{?MODULE,?LINE}]),

    %% N4
    ok=rpc:call(N4,application,start,[leader],5000),
    pong=rpc:call(N4,leader,ping,[],5000),
    timer:sleep(1000),
    N4=rpc:call(N1,leader,who_is_leader,[]),
    false=rpc:call(N1,leader,am_i_leader,[node()],5000),
    false=rpc:call(N1,leader,am_i_leader,[N1],5000),
    false=rpc:call(N3,leader,am_i_leader,[N2],5000),
    false=rpc:call(N3,leader,am_i_leader,[N3],5000),
    true=rpc:call(N1,leader,am_i_leader,[N4],5000),
    io:format("N4 leader OK! ~p~n",[{?MODULE,?LINE}]),

    %% kill N3 
    io:format("kill N3  ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE}]),
    rpc:call(N3,init,stop,[],5000),
    timer:sleep(1500),
    N4=rpc:call(N1,leader,who_is_leader,[]),
    
    %% kill N4
    io:format("kill N4  ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE}]),
    rpc:call(N4,init,stop,[],5000),
    timer:sleep(1500),
    N2=rpc:call(N1,leader,who_is_leader,[]),

    %% restart N3 
    %% Important
    {ok,N3}=test_nodes:start_slave("c3"),
    [rpc:call(N3,net_adm,ping,[N],5000)||N<-AllNodes],
    true=rpc:call(N3,code,add_patha,["ebin"],5000),
    rpc:call(N3,application,load,[leader],5000),
    rpc:call(N3,application,set_env,[[{leader,[{nodes,AllNodes}]}]],5000),
    ok=rpc:call(N3,application,start,[leader],5000),
    pong=rpc:call(N3,leader,ping,[],5000),
    timer:sleep(2000),
    N3=rpc:call(N1,leader,who_is_leader,[]),
    false=rpc:call(N1,leader,am_i_leader,[node()],5000),
    false=rpc:call(N1,leader,am_i_leader,[N1],5000),
    false=rpc:call(N3,leader,am_i_leader,[N2],5000),
    true=rpc:call(N1,leader,am_i_leader,[N3],5000),
    io:format("restart N3 OK!  ~p~n",[{?MODULE,?LINE}]),

    %% restart N4 
    {ok,N4}=test_nodes:start_slave("c4"),
    [rpc:call(N4,net_adm,ping,[N],5000)||N<-AllNodes],
    true=rpc:call(N4,code,add_patha,["ebin"],5000),
    rpc:call(N4,application,load,[leader],5000),
    rpc:call(N4,application,set_env,[[{leader,[{nodes,AllNodes}]}]],5000),
    ok=rpc:call(N4,application,start,[leader],5000),
    pong=rpc:call(N4,leader,ping,[],5000),
    timer:sleep(2000),
    N4=rpc:call(N1,leader,who_is_leader,[]),
    false=rpc:call(N1,leader,am_i_leader,[node()],5000),
    false=rpc:call(N1,leader,am_i_leader,[N1],5000),
    false=rpc:call(N3,leader,am_i_leader,[N2],5000),
    false=rpc:call(N3,leader,am_i_leader,[N3],5000),
    true=rpc:call(N1,leader,am_i_leader,[N4],5000),
    io:format("restart N4 OK!  ~p~n",[{?MODULE,?LINE}]),
    
    
    ok.


%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
setup()->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    ok=test_nodes:start_nodes(),
    [rpc:call(N,code,add_patha,["ebin"],5000)||N<-test_nodes:get_nodes()],     
    
    ok.
