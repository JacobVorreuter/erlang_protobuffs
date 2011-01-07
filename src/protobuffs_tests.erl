-module(protobuffs_tests).
-include_lib("eunit/include/eunit.hrl").

-record(location, {region, country}).
-record(person, {name, address, phone_number, age, location}).
-record(person1, {name, address, phone_number, age, hobbies, locations}).

encode_test() ->
    ?assertEqual(protobuffs:encode(1, 1, uint32), <<8,1>>),
    ?assertEqual(protobuffs:encode(2, 1, uint32), <<16,1>>),
    ?assertEqual(protobuffs:encode(3, 1, uint32), <<24,1>>),
    ok.

decode_test() ->
    Tests = [
        {8, uint32},
        {16, uint32},
        {24, uint32},
        {1, fixed32},
        {1, enum},
        {200, enum},
        {9933, int64},
        {-391, sint64},
        {5, fixed32},
        {-5, sfixed32},
        {30, fixed64},
        {500, sfixed64},
        {"Whirlwind tickles.", string, <<"Whirlwind tickles.">>},
        {"", string, <<>>},
        {<<"It's a secret to everyone.">>, string},
        {<<4,8,15,16,23,42>>, bytes},
        {3.141592025756836, float},
        {1.00000000000000022204460492503130808472633361816406, double}
    ],
    lists:foreach(
        fun(Test) ->
            {Value, Type, Expected} = case Test of
                {A, B} -> {A, B, A};
                _ -> Test
            end,
            Decode = protobuffs:decode(iolist_to_binary(protobuffs:encode(1, Value, Type)), Type),
            ?assertEqual(Decode, {{1, Expected}, <<>>})
        end, Tests),
    ok.

simple_compile_test() ->
    ?assertEqual(protobuffs_compile:scan_file("test/simple.proto"), ok),

    Person = #person{
        name = "Nick",
        address = "Mountain View",
        phone_number = "+1 (000) 555-1234",
        age = 25,
        location = #location{region="CA", country="US"}
    },

    Bin = simple_pb:encode_person(Person),

    ?assertEqual(simple_pb:decode_person(Bin), Person),

    ok.

simple_compile_again_test() ->
    ?assertEqual(protobuffs_compile:scan_file("test/simple.proto"), ok),

    Fields1 = [
        {1, "California", string},
        {2, "USA", string}
    ],

    LocationBinData = erlang:iolist_to_binary([protobuffs:encode(Pos, Value, Type) || {Pos, Value, Type} <- Fields1]),

    Fields2 = [
        {1, "Nick", string},
        {2, "Mountain View", string},
        {3, "+1 (000) 555-1234", string},
        {4, 25, int32},
        {5, LocationBinData, bytes}
    ],

    PersonBinData = erlang:iolist_to_binary([protobuffs:encode(Pos, Value, Type) || {Pos, Value, Type} <- Fields2]),

    Location = #location{region="California", country="USA"},

    Person = #person{
        name = "Nick",
        address = "Mountain View",
        phone_number = "+1 (000) 555-1234",
        age = 25,
        location = Location
    },

    ?assertEqual(simple_pb:encode_location(Location), LocationBinData),
    ?assertEqual(simple_pb:encode_person(Person), PersonBinData),

    ok.

repeater_compile_test() ->
    ?assertEqual(protobuffs_compile:scan_file("test/repeater.proto"), ok),

    Fields1 = [
        {1, "Lyon", string},
        {2, "France", string}
    ],

    Fields2 = [
        {1, "Reykjavik", string},
        {2, "Iceland", string}
    ],

    LocationBinData1 = erlang:iolist_to_binary([protobuffs:encode(Pos, Value, Type) || {Pos, Value, Type} <- Fields1]),
    LocationBinData2 = erlang:iolist_to_binary([protobuffs:encode(Pos, Value, Type) || {Pos, Value, Type} <- Fields2]),

    Fields3 = [
        {1, "Nick", string},
        {2, "Mountain View", string},
        {3, "+1 (000) 555-1234", string},
        {4, 25, int32},
        {5, "paddling", string},
        {5, "floating", string},
        {6, LocationBinData1, bytes},
        {6, LocationBinData2, bytes}
    ],

    PersonBinData1 = erlang:iolist_to_binary([protobuffs:encode(Pos, Value, Type) || {Pos, Value, Type} <- Fields3]),

    Person = #person1{
        name = "Nick",
        address = "Mountain View",
        phone_number = "+1 (000) 555-1234",
        age = 25,
        hobbies = ["paddling", "floating"],
        locations = 
            [#location{region = "Lyon", country = "France"},
             #location{region = "Reykjavik", country = "Iceland"}]
    },

    PersonBinData2 = repeater_pb:encode_person1(Person),

    Person1 = repeater_pb:decode_person1(PersonBinData1),
    Person2 = repeater_pb:decode_person1(PersonBinData2),

    ?assertEqual(PersonBinData1, PersonBinData2),

    ?assertEqual(Person, Person1),

    ?assertEqual(Person1, Person2),

    Person3 = #person1 {
        name = "Nick",
        address = "Mountain View",
        phone_number = "+1 (000) 555-1234",
        age = 25,
        hobbies = ["paddling", "floating"]
    },

    ?assertEqual(repeater_pb:decode_person1(repeater_pb:encode_person1(Person3)), Person3),

    ok.

defaults_compile_test() ->
    ?assertEqual(protobuffs_compile:scan_file("test/hasdefault.proto"), ok),

    Person = #person {
        name = "Nick",
        address = "Mountain View",
        location = #location{region = "Lyon", country = "France"}	
    },

    DefaultPerson = #person{
        name = "Nick",
        address = "Mountain View",
        phone_number = "+1 (000) 000-0000",
        age = 25,
        location = #location{region = "Lyon", country = "France"}
    },

    Bin = hasdefault_pb:encode_person(Person),

    ?assertEqual(hasdefault_pb:decode_person(Bin), DefaultPerson),

    ok.

required_field_test() ->
    ?assertEqual(protobuffs_compile:scan_file("test/hasdefault.proto"), ok),

    ?assertExit({error, {required_field_is_undefined,1,string}}, hasdefault_pb:encode_person(#person{})),

    ok.