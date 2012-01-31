%%%============================================================================
%%% @author Vladimir Darmin <vova@2600hz.org>
%%% @copyright (C) 2011, Vladimir Darmin
%%% @doc
%%% Callflow gen server for CRUD
%%%
%%% @end
%%% Created :  3 Feb 2011 by Vladimir Darmin <vova@2600hz.org>
%%%============================================================================
-module(cb_callflows).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("../../include/crossbar.hrl").

-define(SERVER, ?MODULE).

-define(CALLFLOWS_LIST, <<"callflows/listing_by_id">>).
-define(CB_LIST, <<"callflows/crossbar_listing">>).

%%-----------------------------------------------------------------------------
%% PUBLIC API
%%-----------------------------------------------------------------------------
%%

%------------------------------------------------------------------------------
% @public
% @doc
% Starts the server
%
% @end
%------------------------------------------------------------------------------
-spec start_link/0 :: () -> startlink_ret().
start_link() ->
    gen_server:start_link( {local, ?SERVER}, ?MODULE, [], [] ).

%%-----------------------------------------------------------------------------
%% GEN SERVER CALLBACKS
%%-----------------------------------------------------------------------------
%%

%------------------------------------------------------------------------------
% @private
% @doc
% Initializes the server
%
% @end
%------------------------------------------------------------------------------
init(_) ->
    {ok, ok, 0}.

%------------------------------------------------------------------------------
% @private
% @doc
% Handles call messages
%
% @end
%------------------------------------------------------------------------------
handle_call (_Request, _From, State) ->
   {reply, ok, State}.

%------------------------------------------------------------------------------
% @private
% @doc
% Handles cast messages
%
% @end
%------------------------------------------------------------------------------
handle_cast(_Msg, State) ->
   {noreply, State}.

%------------------------------------------------------------------------------
% @private
% @doc
% Handles all non call/cast messages
%
% @end
%------------------------------------------------------------------------------
handle_info ({binding_fired, Pid, <<"v1_resource.allowed_methods.callflows">>, Payload}, State) ->
    spawn(fun ( ) ->
                  {Result, Payload1} = allowed_methods(Payload),
                  Pid ! { binding_result, Result, Payload1 }
          end),
    {noreply, State};

handle_info ({binding_fired, Pid, <<"v1_resource.resource_exists.callflows">>, Payload}, State) ->
    spawn(fun() ->
                  {Result, Payload1} = resource_exists(Payload),
                  Pid ! {binding_result, Result, Payload1}
          end),
    {noreply, State};

handle_info ({binding_fired, Pid, <<"v1_resource.validate.callflows">>, [RD, Context | Params]}, State) ->
    spawn(fun() ->
                  _ = crossbar_util:put_reqid(Context),
                  _ = crossbar_util:binding_heartbeat(Pid),
                  Context1 = validate(Params, Context),
                  Pid ! {binding_result, true, [RD, Context1, Params]}
         end),
    {noreply, State};

handle_info({binding_fired, Pid, <<"v1_resource.execute.post.callflows">>, [RD, Context | Params]}, State) ->
    spawn(fun() ->
                  _ = crossbar_util:put_reqid(Context),
                  Context1 = case crossbar_doc:save(Context) of
                                #cb_context{account_id=AccountId, doc=JObj, resp_status=success}=C ->
                                     spawn(fun() -> 
                                                   [wh_number_manager:reconcile_number(Number, AccountId)
                                                    || Number <- wh_json:get_value(<<"numbers">>, JObj, [])]
                                           end),
                                    C;
                                Else ->
                                    Else
                            end,
                  Pid ! {binding_result, true, [RD, Context1, Params]}
          end),
    {noreply, State};

handle_info({binding_fired, Pid, <<"v1_resource.execute.put.callflows">>, [RD, Context | Params]}, State) ->
    spawn(fun() ->
                  _ = crossbar_util:put_reqid(Context),
                  Context1 = case crossbar_doc:save(Context) of
                                #cb_context{account_id=AccountId, doc=JObj, resp_status=success}=C ->
                                     spawn(fun() -> 
                                                   [wh_number_manager:reconcile_number(Number, AccountId)
                                                    || Number <- wh_json:get_value(<<"numbers">>, JObj, [])]
                                           end),
                                    C;
                                Else ->
                                    Else
                            end,
                  Pid ! {binding_result, true, [RD, Context1, Params]}
          end),
    {noreply, State};

handle_info({binding_fired, Pid, <<"v1_resource.execute.delete.callflows">>, [RD, Context | Params]}, State) ->
    spawn(fun() ->
                  _ = crossbar_util:put_reqid(Context),
                  Context1 = crossbar_doc:delete(Context),
                  Pid ! {binding_result, true, [RD, Context1, Params]}
          end),
    {noreply, State};

handle_info({binding_fired, Pid, _, Payload}, State) ->
    Pid ! {binding_result, false, Payload},
    {noreply, State};

handle_info(timeout, State) ->
    bind_to_crossbar(),
    {noreply, State};

handle_info (_Info, State) ->
   {noreply, State}.

%------------------------------------------------------------------------------
% @private
% @doc
% Is called by a gen_server when it is about to terminate. It should be the
% opposite of Module:init/1 and do any necessary cleaning up. When it returns,
% the gen_server terminates with Reason. The return value is ignored.
%
% @end
%------------------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%------------------------------------------------------------------------------
% @private
% @doc
% Converts process state when code is changed
%
% @end
%------------------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%-----------------------------------------------------------------------------
%% INTERNAL API
%%-----------------------------------------------------------------------------
%%

%------------------------------------------------------------------------------
% @private
% @doc
% binds this server to the crossbar bindings server for the keys we need to
% consume.
%
% @end
%------------------------------------------------------------------------------
-spec(bind_to_crossbar/0 :: () -> no_return()).
bind_to_crossbar() ->
    _ = crossbar_bindings:bind(<<"v1_resource.allowed_methods.callflows">>),
    _ = crossbar_bindings:bind(<<"v1_resource.resource_exists.callflows">>),
    _ = crossbar_bindings:bind(<<"v1_resource.validate.callflows">>),
    crossbar_bindings:bind(<<"v1_resource.execute.#.callflows">>).

%------------------------------------------------------------------------------
% @private
% @doc
% This function determines the verbs that are appropriate for the given nouns.
%
% @end
%------------------------------------------------------------------------------
-spec (allowed_methods/1 :: (Paths :: list()) -> tuple(boolean(), list(atom()) | [])).
allowed_methods([]) ->
   { true, ['PUT', 'GET'] };                    % PUT - create new callflow
                                                % GET - call flow collection
allowed_methods([_]) ->
   { true, ['GET', 'POST', 'DELETE'] };         % GET    - retrieve callflow
                                                % POST   - update callflow
                                                % DELETE - delete callflow
allowed_methods(_) ->
    { false, [] }.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function determines if the provided list of Nouns are valid.
%%
%% Failure here returns 404
%% @end
%%--------------------------------------------------------------------
-spec(resource_exists/1 :: (Paths :: list()) -> tuple(boolean(), [])).
resource_exists([]) ->
    {true, []};
resource_exists([_]) ->
    {true, []};
resource_exists(_) ->
    {false, []}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function determines if the parameters and content are correct
%% for this request
%%
%% Failure here returns 400
%% @end
%%--------------------------------------------------------------------
-spec(validate/2 :: (Params :: list(), Context :: #cb_context{}) -> #cb_context{}).
validate([], #cb_context{req_verb = <<"get">>}=Context) ->
    load_callflow_summary(Context);
validate([], #cb_context{req_verb = <<"put">>}=Context) ->
    create_callflow(Context);
validate([DocId], #cb_context{req_verb = <<"get">>}=Context) ->
    load_callflow(DocId, Context);
validate([DocId], #cb_context{req_verb = <<"post">>}=Context) ->
    update_callflow(DocId, Context);
validate([DocId], #cb_context{req_verb = <<"delete">>}=Context) ->
    load_callflow(DocId, Context);
validate(_, Context) ->
    crossbar_util:response_faulty_request(Context).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Attempt to load list of accounts, each summarized.  Or a specific
%% account summary.
%% @end
%%--------------------------------------------------------------------
-spec load_callflow_summary/1 :: (#cb_context{}) -> #cb_context{}.
load_callflow_summary(Context) ->
    crossbar_doc:load_view(?CB_LIST, [], Context, fun normalize_view_results/2).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Create a new callflow document with the data provided, if it is valid
%% @end
%%--------------------------------------------------------------------
-spec create_callflow/1 :: (#cb_context{}) -> #cb_context{}.
create_callflow(#cb_context{req_data=Data}=Context) ->
    try [wnm_util:to_e164(Number) || Number <- wh_json:get_value(<<"numbers">>, Data, [])] of
        Numbers ->
            Data1 = wh_json:set_value(<<"numbers">>, Numbers, Data),
            case wh_json_validator:is_valid(Data1, <<"callflows">>) of
                {fail, Errors} ->
                    crossbar_util:response_invalid_data(Errors, Context);
                {pass, JObj} ->
                    Context#cb_context{
                      doc=wh_json:set_value(<<"pvt_type">>, <<"callflow">>, JObj)
                      ,resp_status=success
                     }
            end
    catch
        _:_ ->
            Errs = [wh_json:set_value([<<"numbers">>, <<"type">>], <<"Value is not of type array">>, wh_json:new())],
            crossbar_util:response_invalid_data(Errs, Context)
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Load a callflow document from the database
%% @end
%%--------------------------------------------------------------------
-spec load_callflow/2 :: (ne_binary(), #cb_context{}) -> #cb_context{}.
load_callflow(DocId, Context) ->
    case crossbar_doc:load(DocId, Context) of
        #cb_context{resp_status=success, doc=Doc, resp_data=Data, db_name=Db}=Context1 ->
            Meta = get_metadata(wh_json:get_value(<<"flow">>, Doc), Db, wh_json:new()),
            Context1#cb_context{resp_data=wh_json:set_value(<<"metadata">>, Meta, Data)};
        Else ->
            Else
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Update an existing callflow document with the data provided, if it is
%% valid
%% @end
%%--------------------------------------------------------------------
-spec update_callflow/2 :: (ne_binary(), #cb_context{}) -> #cb_context{}.
update_callflow(DocId, #cb_context{req_data=Data}=Context) ->
    Numbers = [wnm_util:to_e164(Number) || Number <- wh_json:get_value(<<"numbers">>, Data, [])],
    Data1 = wh_json:set_value(<<"numbers">>, Numbers, Data),
    case wh_json_validator:is_valid(Data1, <<"callflows">>) of
        {fail, Errors} ->
            crossbar_util:response_invalid_data(Errors, Context);
        {pass, JObj} ->
            crossbar_doc:load_merge(DocId, JObj, Context)
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Normalizes the resuts of a view
%% @end
%%--------------------------------------------------------------------
-spec normalize_view_results/2 :: (wh_json:json_object(), wh_json:json_objects()) -> wh_json:json_objects().
normalize_view_results(JObj, Acc) ->
    [wh_json:get_value(<<"value">>, JObj)|Acc].

%%--------------------------------------------------------------------
%% @private
%% @doc
%% collect addional informat about the objects referenced in the flow
%% @end
%%--------------------------------------------------------------------
-spec get_metadata/3 :: ('undefined' | wh_json:json_object(), ne_binary(), wh_json:json_object()) -> wh_json:json_object().
get_metadata(undefined, _, JObj) ->
    JObj;
get_metadata(Flow, Db, JObj) ->
    JObj1 = case wh_json:get_value([<<"data">>, <<"id">>], Flow) of
                %% this node has no id, dont change the metadata
                undefined -> JObj;
                %% node has an id, try to update the metadata
                Id -> create_metadata(Db, Id, JObj)
            end,
    case wh_json:get_value(<<"children">>, Flow) of
        undefined -> JObj1;
        Children ->
            %% iterate through each child, collecting metadata on the
            %% branch name (things like temporal routes)
            lists:foldr(fun({K, Child}, J) ->
                                get_metadata(Child, Db, create_metadata(Db, K, J))
                        end, JObj1, wh_json:to_proplist(Children))
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Given the metadata json object, an ID and a db find the document
%% and add the fields to the metadata.  However, skip if the ID already
%% exists in metadata.
%% @end
%%--------------------------------------------------------------------
-spec create_metadata/3 :: (Db, Id, JObj) -> wh_json:json_object() when
      Db :: binary(),
      Id :: binary(),
      JObj :: wh_json:json_object().
create_metadata(Db, Id, JObj) ->
    case wh_json:get_value(Id, JObj) =:= undefined
        andalso couch_mgr:open_doc(Db, Id) of
        false  ->
            %% the id already exists in the metadata
            JObj;
        {ok, Doc} ->
            %% the id was found in the db
            wh_json:set_value(Id, create_metadata(Doc), JObj);
        _ ->
            %% eh, whatevs
            JObj
    end.

-spec create_metadata/1 :: (Doc) -> wh_json:json_object() when
      Doc :: wh_json:json_object().
create_metadata(Doc) ->
    %% simple funciton for setting the same key in one json object
    %% with the value of that key in another, unless it doesnt exist
    Metadata = fun(<<"name">> = K, D, J) ->
                       case wh_json:get_value(<<"pvt_type">>, D) of
                           <<"user">> ->
                               Name = <<(wh_json:get_binary_value(<<"first_name">>, D, <<>>))/binary
                                        ," "
                                        ,(wh_json:get_binary_value(<<"last_name">>, D, <<>>))/binary>>,
                               case Name of
                                   <<>> -> J;
                                   _ -> wh_json:set_value(<<"name">>, Name, J)
                               end;
                           _ ->
                               case wh_json:get_value(K, D) of
                                   undefined -> J;
                                   V -> wh_json:set_value(K, V, J)
                               end
                       end;
                  (K, D, J) ->
                       case wh_json:get_value(K, D) of
                           undefined -> J;
                           V -> wh_json:set_value(K, V, J)
                       end
               end,
    %% list of keys to extract from documents and set on the metadata
    Funs = [fun(D, J) -> Metadata(<<"name">>, D, J) end,
            fun(D, J) -> Metadata(<<"numbers">>, D, J) end,
            fun(D, J) -> Metadata(<<"pvt_type">>, D, J) end],
    %% do it
    lists:foldl(fun(Fun, JObj) ->
                         Fun(Doc, JObj)
                end, wh_json:new(), Funs).
