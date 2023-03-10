%%%-------------------------------------------------------------------
%% @doc org top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(leader_sup).

-behaviour(supervisor).

-export([start_link/1]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link(Nodes) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, Nodes).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init(Nodes) ->
  %  io:format("Nodes ~p~n",[{Nodes,?MODULE,?FUNCTION_NAME,?LINE}]),
    SupFlags = #{strategy => one_for_all,
                 intensity => 0,
                 period => 1},
    ChildSpecs = [#{id=>leader,
		    start=>{leader,start,[Nodes]}}],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
