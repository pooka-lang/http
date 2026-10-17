%% SPDX-License-Identifier: Apache-2.0

%%% HTTP field names use ASCII folding. Unicode casing belongs to prose;
%%% a header name has a smaller alphabet and needs no locale.
-module(pooka_http_ffi).
-export([lowercase/1, validate_request/8, validate_cookie/6]).

%% <<"Content-Type">> becomes <<"content-type">>; other bytes stay put.
lowercase(Text) -> << <<(ascii_lower(C))>> || <<C>> <= Text >>.

ascii_lower(C) when C >= $A, C =< $Z -> C + 32;
ascii_lower(C) -> C.

%% No bytes are sent here. Validation is shared by clients and server adapters,
%% including callers that constructed Request directly instead of parsing a URL.
validate_request(Method, Scheme, Host, Port, Path, Query, Headers, Body) ->
    Checks = [
        {token(Method), <<"a method must be a nonempty HTTP token">>},
        {Scheme =:= <<"http">> orelse Scheme =:= <<"https">>, <<"HTTP URLs must use http or https">>},
        {valid_host(Host), <<"an HTTP host must not contain URL delimiters or whitespace">>},
        {valid_port(Port), <<"a port must be between 1 and 65535">>},
        {valid_path(Path), <<"a request path must start with / and contain no raw whitespace, query or fragment">>},
        {valid_query(Query), <<"a query must contain no raw whitespace or fragment">>},
        {lists:all(fun({N, V}) -> token(N) andalso field_value(V) end, Headers),
         <<"headers need token names and values without control characters">>},
        {is_binary(Body), <<"an HTTP body must contain whole bytes">>},
        {not lists:any(fun({N, _}) ->
            lists:member(lowercase(N), [<<"content-length">>, <<"transfer-encoding">>])
        end, Headers), <<"let the transport set content-length and transfer-encoding">>}
    ],
    checked(Checks).

valid_host(Host) ->
    Host =/= <<>> andalso lists:all(fun(C) ->
        C > 32 andalso C < 127 andalso not lists:member(C, "/?#@\\")
    end, binary_to_list(Host)).

valid_port(none) -> true;
valid_port({some, N}) -> is_integer(N) andalso N >= 1 andalso N =< 65535.

valid_path(<<"/", _/binary>> = Path) ->
    url_component(Path) andalso binary:match(Path, [<<"?">>, <<"#">>]) =:= nomatch;
valid_path(_) -> false.

valid_query(none) -> true;
valid_query({some, Text}) ->
    url_component(Text) andalso binary:match(Text, <<"#">>) =:= nomatch.

url_component(Text) ->
    lists:all(fun(C) -> C > 32 andalso C < 127 end, binary_to_list(Text)).

token(<<>>) -> false;
token(Text) ->
    lists:all(fun(C) ->
        (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z) orelse
        (C >= $0 andalso C =< $9) orelse lists:member(C, "!#$%&'*+-.^_`|~")
    end, binary_to_list(Text)).

field_value(Text) ->
    lists:all(fun(C) -> C =:= 9 orelse (C >= 32 andalso C =/= 127) end,
              binary_to_list(Text)).

%% Cookie octets are deliberately narrower than header values: a semicolon
%% would start another attribute, even though it is legal in an ordinary field.
validate_cookie(Name, Value, Path, Domain, Secure, SameSite) ->
    checked([
        {token(Name), <<"a cookie name must be an HTTP token">>},
        {lists:all(fun cookie_octet/1, binary_to_list(Value)), <<"a cookie value contains a forbidden byte">>},
        {attribute(Path), <<"a cookie path contains a forbidden byte">>},
        {case Domain of none -> true; {some, D} -> valid_domain(D) end,
         <<"a cookie domain must be a host name">>},
        {SameSite =/= <<"None">> orelse Secure, <<"SameSite=None requires Secure">>},
        {not prefix(<<"__Secure-">>, Name) orelse Secure, <<"__Secure- cookies require Secure">>},
        {not prefix(<<"__Host-">>, Name) orelse
            (Secure andalso Path =:= <<"/">> andalso Domain =:= none),
         <<"__Host- cookies require Secure, Path=/ and no Domain">>}
    ]).

cookie_octet(C) -> C =:= 16#21 orelse
    (C >= 16#23 andalso C =< 16#2B) orelse
    (C >= 16#2D andalso C =< 16#3A) orelse
    (C >= 16#3C andalso C =< 16#5B) orelse
    (C >= 16#5D andalso C =< 16#7E).

attribute(Text) -> lists:all(fun(C) -> C >= 32 andalso C < 127 andalso C =/= $; end,
                            binary_to_list(Text)).
valid_domain(<<>>) -> false;
valid_domain(Text) -> lists:all(fun(C) ->
    (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z) orelse
    (C >= $0 andalso C =< $9) orelse C =:= $. orelse C =:= $-
end, binary_to_list(Text)).

prefix(Prefix, Text) -> binary:match(Text, Prefix) =:= {0, byte_size(Prefix)}.

checked([]) -> {ok, nil};
checked([{true, _} | Rest]) -> checked(Rest);
checked([{false, Message} | _]) -> {error, Message}.
