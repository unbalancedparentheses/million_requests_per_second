-module(mrps_genserver_protocol).

-behaviour(ranch_protocol).
-behaviour(gen_server).

-export([start_link/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).


%% ranch_protocol
start_link(ListenerPid, Socket, Transport, [Register]) ->
    Pid = proc_lib:spawn_link(?MODULE, init, [[ListenerPid, Socket, Transport, Register]]),
    {ok, Pid}.

%% gen_server
init([ListenerPid, _Socket, Transport, Register]) ->
    {ok, Socket} = ranch:handshake(ListenerPid),
    Register:store_client(self()),
    ok = Transport:setopts(Socket, [{nodelay, true}, {active, once}]),

    Transport:send(Socket, <<"connected\n">>),
    gen_server:enter_loop(?MODULE, [], 
        #{socket => Socket, transport => Transport, register => Register}).

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({msg, Message}, State=#{socket := Socket, transport := Transport}) ->
    Transport:send(Socket, Message),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({tcp, _Socket, <<"SEND", Message/binary>>}, 
            State=#{socket := Socket, transport := Transport, register := Register}) ->
    Register:for_each(send_msg(Message, self())),
    ok = Transport:setopts(Socket, [{active, once}]),
    {noreply, State};
handle_info({tcp, _Socket, <<"COUNT\n">>}, 
            State=#{socket := Socket, transport := Transport, register := Register}) ->
    Count = integer_to_binary(Register:count()),
    ok = Transport:send(Socket, [Count, <<"\n">>]),
    ok = Transport:setopts(Socket, [{active, once}]),
    {noreply, State};
handle_info({tcp, _Socket, _Data}, 
            State=#{socket := Socket, transport := Transport}) ->
    ok = Transport:setopts(Socket, [{active, once}]),
    {noreply, State};
handle_info({tcp_closed, _Socket}, State) ->
    {stop, normal, State};
handle_info({tcp_error, _Socket, Reason}, State) ->
    {stop, Reason, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #{socket := Socket, transport := Transport, register := Register}) ->
    ok = Transport:close(Socket),
    Register:remove_client(self()),
    ok.

send_msg(Message, Sender) ->
    fun (Client) when Client =:= Sender ->
            pass;
        (Client) ->
            gen_server:cast(Client, {msg, Message})
    end.
