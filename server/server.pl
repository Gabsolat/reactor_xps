%% server.pl -- HTTP entry point.  Run: swipl -q -s server/server.pl -g start -t halt   (PORT env var honoured)
:- ensure_loaded('../src/main').
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- ensure_loaded(api).

:- dynamic server_dir/1.
:- prolog_load_context(directory, D), asserta(server_dir(D)).

:- http_handler(root(.),            serve_index,  []).
:- http_handler(root(api/health),   api_health,   []).
:- http_handler(root(api/cases),    api_cases,    []).
:- http_handler(root(api/case),     api_case,     []).
:- http_handler(root(api/reference),api_reference,[]).
:- http_handler(root(api/kb),       api_kb,       []).
:- http_handler(root(api/evaluate), api_evaluate, []).
:- http_handler(root(api/diagnose), api_diagnose, [method(post)]).
:- http_handler(root(api/batch),    api_batch,    [method(post)]).
:- http_handler(root(api/experiment), api_experiment, []).
:- http_handler(root(static),       serve_static, [prefix]).

serve_index(Request) :-
    server_dir(D), atomic_list_concat([D, '/static/index.html'], F),
    % unsafe(true): F is an absolute path built by the server itself (never from user input)
    http_reply_file(F, [unsafe(true)], Request).

serve_static(Request) :-
    server_dir(D), atomic_list_concat([D, '/static'], S),
    http_reply_from_files(S, [], Request).

start :-
    (   getenv('PORT', P0), atom_number(P0, Port) -> true ; Port = 8080 ),
    http_server(http_dispatch, [port(Port)]),
    format("Reactor expert system listening on port ~w~n", [Port]),
    thread_get_message(_).
