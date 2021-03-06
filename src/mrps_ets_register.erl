-module(mrps_ets_register).

-behaviour(mrps_register).

-export([init/1, store_client/1, remove_client/1, for_each/1, count/0]).

init(_Args) ->
    ets:new(clients, [set, public, named_table]).

store_client(Client) ->
    ets:insert(clients, {Client}).

remove_client(Client) ->
    ets:delete(clients, Client).

for_each(Func) ->
    ets:foldl(
        fun({Client}, _Acc) -> Func(Client) end, 
        [],
        clients  
    ).

count() ->
    ets:info(clients, size).
