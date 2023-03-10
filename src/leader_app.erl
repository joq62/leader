%%%-------------------------------------------------------------------
%% @doc org public API
%% @end
%%%-------------------------------------------------------------------

-module(leader_app).

-behaviour(application).

-export([start/2, stop/1]).
-define(Application,leader).

start(_StartType, _StartArgs) ->
   % io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME,?LINE}]),
    case application:get_env(?Application,nodes) of
	undefined->
	    leader_sup:start_link([node()]);
	{ok,AllNodes}->
	    leader_sup:start_link(AllNodes)
    end.

stop(_State) ->
    ok.

%% internal functions
