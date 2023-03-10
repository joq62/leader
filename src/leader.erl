%%%-------------------------------------------------------------------
%%% @author c50 <joq62@c50>
%%% @copyright (C) 2023, c50
%%% @doc
%%%
%%% @end
%%% Created :  5 Mar 2023 by c50 <joq62@c50>
%%%-------------------------------------------------------------------
-module(leader).

-behaviour(gen_server).
%% Server API
-export([who_is_leader/0,
	 am_i_leader/1,
	 ping/0]).



%% fms signals
-define(COORDINATOR_SERVER, ?MODULE).
-export([
	 start_election/0,
	 declare_victory/1,
	 i_am_alive/1,
	 timeout_election/0
	]).


-define(ELECTION_RESPONSE_TIMEOUT, 3*50).

%% states
-define(ELECTION_STATE,election).
-define(CANDIDATE_STATE,candidate).
-define(LEADER_STATE,leader).

%% API
-export([start/1
	 ]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-define(SERVER, ?MODULE).



-record(state, {leader,
		fsm_state,
		nodes,
		timeout_pid}).

%%%===================================================================
%%% API
%%%===================================================================
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
who_is_leader()->
    gen_server:call(?SERVER, {who_is_leader},infinity).
am_i_leader(Node)->
    gen_server:call(?SERVER, {am_i_leader,Node},infinity).
ping()->
    gen_server:call(?SERVER, {ping},infinity).

start_election()->
    gen_server:cast(?SERVER,{start_election}).
declare_victory(Node)->
    gen_server:cast(?SERVER,{declare_victory,Node}).
i_am_alive(Node)->
    gen_server:cast(?SERVER,{i_am_alive,Node}).
timeout_election()->
    gen_server:cast(?SERVER,{timeout_election}).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
start(Nodes)->
    start_link(Nodes).

-spec start_link(Nodes::[]) -> {ok, Pid :: pid()} |
	  {error, Error :: {already_started, pid()}} |
	  {error, Error :: term()} |
	  ignore.
start_link(Nodes) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Nodes, []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
	  {ok, State :: term(), Timeout :: timeout()} |
	  {ok, State :: term(), hibernate} |
	  {stop, Reason :: term()} |
	  ignore.
init(Nodes) ->
    ServerPid=self(),
    Pid=spawn(fun()->timeout_loop(ServerPid,infinity) end),
    send_start_election(Nodes),
    set_election_timer(Pid,?ELECTION_RESPONSE_TIMEOUT),
    
    {ok, #state{
	    leader=undefined,
	    fsm_state=election,
	    timeout_pid=Pid,
	    nodes=Nodes}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
handle_call({who_is_leader}, _From, State) ->
    Reply = State#state.leader,
    {reply, Reply, State};

handle_call({am_i_leader,Node}, _From, State) ->
    Reply = if 
		Node/=State#state.leader ->
		    false;
		true->
		    true
	    end,
		
    {reply, Reply, State};

handle_call({ping}, _From, State) ->
    Reply = pong,
    {reply, Reply, State};

handle_call(Request, _From, State) ->
    io:format("Unmatched signal ~p~n",[{Request,?MODULE,?LINE}]),
    Reply = {error,[unmatched_signal,Request]},
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------

%% state election -----------------------------------------------------
handle_cast({start_election}, #state{fsm_state=election}=State) ->
%    io:format(" ~p~n",[{start_election,election,node(),?MODULE,?LINE}]),
    send_start_election(State#state.nodes),
    set_election_timer(State#state.timeout_pid,?ELECTION_RESPONSE_TIMEOUT),
    NewState=State,
    {noreply, NewState};

handle_cast({declare_victory,LeaderNode}, #state{fsm_state=election}=State) ->
 %   io:format(" ~p~n",[{declare_victory,LeaderNode,election,node(),?MODULE,?LINE}]),
    case LeaderNode==node() of
	true->
	    NewState=State#state{leader=node()};
	false->
	    monitor_node(State#state.leader, false),
	    monitor_node(LeaderNode, true),
	    NewState=State#state{leader=LeaderNode,
				 fsm_state=candidate}
    end,
    {noreply, NewState};

handle_cast({i_am_alive,HigherNode}, #state{fsm_state=election}=State) ->
 %   io:format(" ~p~n",[{i_am_alive,HigherNode,election,node(),?MODULE,?LINE}]),
    set_election_timer(State#state.timeout_pid,infinity),
    NewState=State,
    {noreply, NewState};

handle_cast({timeout_election}, #state{fsm_state=election}=State) ->
 %   io:format(" ~p~n",[{timeout_election,election,node(),?MODULE,?LINE}]),
    send_declare_victory(State#state.nodes),
    set_election_timer(State#state.timeout_pid,infinity),
    NewState=State#state{fsm_state=leader,
			 leader=node()},
    {noreply, NewState};

%% state candidate -----------------------------------------------------
handle_cast({start_election}, #state{fsm_state=candidate}=State) ->
 %   io:format(" ~p~n",[{start_election,candidate,node(),?MODULE,?LINE}]),
    send_i_am_alive(State#state.nodes),
    send_start_election(State#state.nodes),
    set_election_timer(State#state.timeout_pid,?ELECTION_RESPONSE_TIMEOUT),
    NewState=NewState=State#state{fsm_state=election},
    {noreply, NewState};

handle_cast({i_am_alive,_HigherNode}, #state{fsm_state=candidate}=State) ->
%   io:format(" ~p~n",[{i_am_alive,_HigherNode,candidate,node(),?MODULE,?LINE}]),
    NewState=State,
    {noreply, NewState};

handle_cast({declare_victory,LeaderNode}, #state{fsm_state=candidate}=State) ->
%   io:format(" ~p~n",[{declare_victory,LeaderNode,candidate,node(),?MODULE,?LINE}]),
    monitor_node(State#state.leader, false),
    monitor_node(LeaderNode, true),
    NewState=State#state{leader=LeaderNode},
    {noreply, NewState};

handle_cast({timeout_election}, #state{fsm_state=candidate}=State) ->
%    io:format(" ~p~n",[{timeout_election,candidate,node(),?MODULE,?LINE}]),
    set_election_timer(State#state.timeout_pid,infinity),
    NewState=State,
    {noreply, NewState};

%% state leader -----------------------------------------------------
handle_cast({start_election}, #state{fsm_state=leader}=State) ->
%    io:format(" ~p~n",[{start_election,leader,node(),?MODULE,?LINE}]),
    send_i_am_alive(State#state.nodes),
    send_start_election(State#state.nodes),
    set_election_timer(State#state.timeout_pid,?ELECTION_RESPONSE_TIMEOUT),
    NewState=NewState=State#state{fsm_state=election},
    {noreply, NewState};

handle_cast({i_am_alive,_HigherNode}, #state{fsm_state=leader}=State) ->
 %   io:format(" ~p~n",[{i_am_alive,_HigherNode,leader,node(),?MODULE,?LINE}]),
    NewState=State,
    {noreply, NewState};

handle_cast({declare_victory,LeaderNode}, #state{fsm_state=leader}=State) ->
 %  io:format(" ~p~n",[{declare_victory,LeaderNode,leader,node(),?MODULE,?LINE}]),
    case LeaderNode==node() of
	true->
	    NewState=State#state{leader=node()};
	false->
	    monitor_node(State#state.leader, false),
	    monitor_node(LeaderNode, true),
	    NewState=State#state{leader=LeaderNode,
				 fsm_state=candidate}
    end,
    {noreply, NewState};

handle_cast({timeout_election}, #state{fsm_state=leader}=State) ->
 %   io:format(" ~p~n",[{timeout_election,leader,node(),?MODULE,?LINE}]),
    set_election_timer(State#state.timeout_pid,infinity),
    NewState=State,
    {noreply, NewState};

handle_cast(Request, State) ->
    io:format("Unmatched signal ~p~n",[{Request,?MODULE,?LINE}]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
handle_info({nodedown,Node}, State) ->
    case Node==State#state.leader of
	true->
	    send_start_election(State#state.nodes),
	    set_election_timer(State#state.timeout_pid,?ELECTION_RESPONSE_TIMEOUT),
	    NewState=State#state{fsm_state=election};
	false->
	    NewState=State
    end,
    {noreply, NewState};

handle_info(Info, State) ->
    io:format("Unmatched signal ~p~n",[{Info,?MODULE,?LINE}]),
    {noreply, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
		State :: term()) -> any().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn :: term() | {down, term()},
		  State :: term(),
		  Extra :: term()) -> {ok, NewState :: term()} |
	  {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt :: normal | terminate,
		    Status :: list()) -> Status :: term().
format_status(_Opt, Status) ->
    Status.

%%%===================================================================
%%% Internal functions
%%%===================================================================
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
set_election_timer(Pid,Timeout)->
    Pid!{self(),Timeout}.


timeout_loop(ServerPid,TimeOut)->
    receive
	{ServerPid,NewTimeOut}->
	    ok
    after
	TimeOut->
	    NewTimeOut=infinity,
	    rpc:cast(node(),?MODULE,timeout_election,[])
    end,
    timeout_loop(ServerPid,NewTimeOut).
       
	
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
send_start_election(Nodes)->
    HigherNodes=nodes_with_higher_ids(Nodes),
  %  io:format("HigherNodes  ~p~n",[{HigherNodes,node(),?MODULE,?LINE}]),
    [rpc:cast(N,?MODULE,start_election,[])||N<-HigherNodes].
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
send_declare_victory(Nodes)->
    LowerNodes=nodes_with_lower_ids(Nodes),
  %  io:format("LowerNodes  ~p~n",[{LowerNodes,node(),?MODULE,?LINE}]),
    [rpc:cast(N,?MODULE,declare_victory,[node()])||N<-LowerNodes].
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
send_i_am_alive(Nodes)->
    LowerNodes=nodes_with_lower_ids(Nodes),
  %  io:format("LowerNodes  ~p~n",[{LowerNodes,node(),?MODULE,?LINE}]),
    [rpc:cast(N,?MODULE,i_am_alive,[node()])||N<-LowerNodes].


%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
nodes_with_higher_ids(Nodes) ->
  [Node || Node <- Nodes, Node > node()].

nodes_with_lower_ids(Nodes) ->
  [Node || Node <- Nodes, Node < node()].
