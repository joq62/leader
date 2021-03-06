%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description : resource discovery accroding to OPT in Action 
%%% This service discovery is adapted to 
%%% Type = application 
%%% Instance ={ip_addr,{IP_addr,Port}}|{erlang_node,{ErlNode}}
%%% 
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(leader).
 
-behaviour(gen_server). 

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
-define(ELECTION_RESPONSE_TIMEOUT,3*100).
-define(CHECK_CONSISTENCE_INTERVAL,10*1000).

%%% bully algorithm messages
-define(ELECTION_MESSAGE, election).
-define(ELECTION_RESPONSE, i_am_alive).
-define(COORDINATOR_MESSAGE, coordinator).


-define(SERVER,leader).

%% External exports
-export([
	 election/1,
	 election_response/1,
	 coordinator_message/1,

	 start_election/0,
	 status/0,
	 who_is_leader/0,
	 am_i_leader/1,
	

	 appl_start/1,
	 ping/0
	]).

-export([
	 start/0,
	 stop/0]).


%% gen_server callbacks



-export([init/1, handle_call/3,handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {nodes,
		application_to_track,
		coordinator_node}).

%% ====================================================================
%% External functions
%% ====================================================================
appl_start([])->
    application:start(?MODULE).


start()-> 
    gen_server:start_link({local, ?SERVER}, ?SERVER, [], []).
stop()-> gen_server:call(?SERVER, {stop},infinity).


%%----------------------------------------------------------
start_election()->
    gen_server:cast(?SERVER,{start_election}).

election(Node)->
    gen_server:cast(?SERVER,{election,Node}).

election_response(Node)->
     gen_server:cast(?SERVER,{election_response,Node}).

%%----------------------------------------------------------

status()->
    gen_server:call(?SERVER,{status},infinity).

who_is_leader()->
    gen_server:call(?SERVER,{who_is_leader},infinity).
am_i_leader(CallingNode)->
    gen_server:call(?SERVER,{am_i_leader,CallingNode},infinity).
   
coordinator_message(CoordinatorNode)->
     gen_server:cast(?SERVER,{coordinator_message,CoordinatorNode}).

%check_consistence()->
 %    gen_server:cast(?SERVER,{check_consistence}).


ping()-> gen_server:call(?SERVER, {ping},infinity).

%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
    {ok,Application}=application:get_env(application_to_track),
    Coordinator=case sd:get(leader) of
		    []->
			node();
		    Leaders->
			rpc:cast(node(),leader,start_election,[]),
			[{Leader,_}|_]=Leaders,
			rpc:call(Leader,leader,who_is_leader,[],5000)
		end,		
    monitor_node(Coordinator, true),
    rpc:cast(node(),nodelog,log,[notice,?MODULE_STRING,?LINE,
				      {"OK, started server at node  ",?MODULE," ",node()}]),
    {ok, #state{nodes = glurk_to_be_removed,
		application_to_track=Application,
		coordinator_node = Coordinator}}.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

handle_call({who_is_leader},_From, State) ->
    Reply = State#state.coordinator_node,
    {reply, Reply, State};
handle_call({am_i_leader,CallingNode},_From, State) ->
    Reply =State#state.coordinator_node=:=CallingNode,
    {reply, Reply, State};
handle_call({status},_From, State) ->
    Reply = State,
    {reply, Reply, State};

handle_call({ping},_From, State) ->
    Reply = pong,
    {reply, Reply, State};

handle_call({stop}, _From, State) ->
    {stop, normal, shutdown_ok, State};

handle_call(Request, From, State) ->
    Reply = {unmatched_signal,?MODULE,Request,From},
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast({start_election}, State) ->
   % io:format("Election started by node ~p~n", [node()]),

    Nodes=[Node||{Node,_}<-sd:get(State#state.application_to_track)],
    NodesLowerId=nodes_with_lower_ids(Nodes),
    [rpc:cast(Node,leader,election,[node()])||Node<-NodesLowerId],
    {noreply, State,?ELECTION_RESPONSE_TIMEOUT};

handle_cast({election,Node}, State) ->
 %   io:format("Election  ~p~n", [node()]),
    case Node > node() of
	true-> 
	    rpc:cast(Node,leader,election_response,[node()]),
	    rpc:cast(node(),leader,start_election,[]);
	false-> % lost election
	    ok   
    end,
    {noreply, State};

handle_cast({election_response,_Node}, State) ->
 %   io:format("Node ,i_am_alive ~p~n",[{node(),Node}]),
    {noreply, State};

handle_cast({coordinator_message,CoordinatorNode}, State) ->
    NewState=set_coordinator(State, CoordinatorNode),
    {noreply, NewState};

handle_cast(Msg, State) ->
    io:format("unmatched match cast ~p~n",[{Msg,?FUNCTION_NAME,?MODULE,?LINE}]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info(timeout,State) -> 
    NewState=win_election(State),
    {noreply, NewState};

handle_info({nodedown,Node},State) -> 
    CoordinatorNode=State#state.coordinator_node,
    case Node of
	CoordinatorNode->
	    rpc:cast(node(),nodelog,log,[warning,?MODULE_STRING,?LINE,
					{"CoordinatorNode down, ",State#state.coordinator_node}]),
	    timer:sleep(1000),
	    rpc:cast(node(),leader,start_election,[]);
	_->
	    rpc:cast(node(),nodelog,log,[notice,?MODULE_STRING,?LINE,
					{"Node down, ",Node}])
    end,
	    
    {noreply, State};

handle_info(Info, State) ->
    io:format("unmatched match Info ~p~n",[{Info,?FUNCTION_NAME,?MODULE,?LINE}]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Exported functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------


%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
win_election(State)->
    Nodes=[Node||{Node,_}<-sd:get(State#state.application_to_track)],
    NodesHigherId=nodes_with_higher_ids(Nodes),
    [rpc:cast(Node,leader,coordinator_message,[node()])||Node<-NodesHigherId],
    set_coordinator(State, node()).

set_coordinator(State,Coordinator)->
    rpc:cast(node(),nodelog,log,[notice,?MODULE_STRING,?LINE,
				 {"DEBUG  Oldccordinator, New coordinator, ", State#state.coordinator_node," ",Coordinator}]),
%    io:format("Node ~p has changed leader from ~p to ~p~n", [node(), State#state.coordinator_node, Coordinator]),
    monitor_node(State#state.coordinator_node, false),
    monitor_node(Coordinator, true),
    State#state{coordinator_node = Coordinator}.


%% --------------------------------------------------------------------
%% Function:start/0 
%% Description: Initiate the eunit tests, set upp needed processes etc
%% Returns: non
%% --------------------------------------------------------------------
nodes_with_higher_ids(Nodes) ->
  [Node || Node <- Nodes, Node > node()].

nodes_with_lower_ids(Nodes) ->
  [Node || Node <- Nodes, Node < node()].
