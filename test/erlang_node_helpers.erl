-module(erlang_node_helpers).

-export([start_erlang_nodes/2, start_erlang_node/2, stop_erlang_nodes/1, stop_erlang_node/1, wait_for_stop/2]).
-include_lib("common_test/include/ct.hrl").

start_erlang_nodes(Nodes, Config) ->
    [start_erlang_node(Node, Config) || Node <- Nodes].

start_erlang_node(Node, Config) ->
    DistMod = ?config(erlang_dist_module, Config),
    StartArgs = case DistMod of
                    undefined ->
                        "";
                    _ ->
                        DistModS = atom_to_list(DistMod),
                        DistModPath = filename:absname(
                                        filename:dirname(
                                          code:where_is_file(DistModS ++ ".beam"))),
                        DistArg = re:replace(DistModS, "_dist$", "",
                                             [{return, list}]),
                        "-pa \"" ++ DistModPath ++ "\" -proto_dist " ++ DistArg
                end,
    ct:pal("Start args: '~s'~n", [StartArgs]),
    NodeName =
        case ct_slave:start(Node, [{erl_flags, StartArgs}]) of
            {ok, N} -> N;
            {error, _, N} -> N
        end,
    wait_for_distribution(NodeName, 50),
    add_lib_dir(NodeName),
    NodeName.

add_lib_dir(Node) ->
    ct_rpc:call(Node, code, add_paths, [code:get_path()]).

wait_for_distribution(Node, 0) ->
    error({distribution_failed_for, Node, no_more_attempts});
wait_for_distribution(Node, Attempts) ->
    ct:pal("Waiting for node ~p~n", [Node]),
    case ct_rpc:call(Node, net_kernel, set_net_ticktime, [10]) of
        {badrpc, nodedown} ->
            timer:sleep(100),
            wait_for_distribution(Node, Attempts - 1);
        _ -> ok
    end.

stop_erlang_nodes(Nodes) ->
    [stop_erlang_node(Node) || Node <- Nodes].

stop_erlang_node(Node) ->
    ct:pal("Stopping node ~p~n", [Node]),
    ct_slave:stop(Node),
    wait_for_stop(Node, 100).

wait_for_stop(Node, 0) ->
    error({stop_failed_for, Node});
wait_for_stop(Node, Attempts) ->
    case ct_rpc:call(Node, erlang, node, []) of
        {badrpc, nodedown} -> ok;
        _ ->
            timer:sleep(100),
            wait_for_stop(Node, Attempts - 1)
    end.
