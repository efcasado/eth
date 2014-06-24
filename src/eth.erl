%%%=============================================================================
%%% eth.erl
%%%
%%% A utility module for handling (Layer 2) Ethernet frames in Erlang.
%%%
%%% Author: Enrique Fernández <efcasado@gmail.com>
%%% Date:   June, 2014
%%%
%%% License:
%%% The MIT License (MIT)
%%%
%%% Copyright (c) 2014 Enrique Fernández
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"),
%%% to deal in the Software without restriction, including without limitation
%%% the rights to use, copy, modify, merge, publish, distribute, sublicense,
%%% and/or sell copies of the Software, and to permit persons to whom the
%%% Software is furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%%=============================================================================
-module(eth).

-export([
         decode/1, encode/1,
         mac_to_str/1, str_to_mac/1,
         src/1, dst/1,
         is_multicast/1
        ]).

%% Record used for representing Ethernet frames.
-record(eth,
        {
          %% Source MAC address
          dst :: mac_addr(),
          %% Destination MAC address
          src :: mac_addr(),
          %% 802.1Q's priority level
          pcp,
          %% 802.1Q's drop elegible indicator
          drop,
          %% 802.1Q's VLAN id
          vlan_id,
          type,
          %% Payload of the L2 Ethernet frame
          data :: binary(),
          crc :: non_neg_integer(),
          %% Tells if the Ethernet frame is a multicast frame or not
          multicast = 'false' :: boolean()
        }).

%% Type definitions
-type raw_eth_frame() :: binary(). % raw Ethernet frame
-type eth_frame() :: #eth{}.       % record representation of an Ethernet frame
-type raw_mac_addr() :: binary().  % raw MAC address
-type mac_addr() :: string().      % string representation of a MAC address

%% Macro definitions
-define('802.1Q', 16#8100). % IEEE 802.1Q protocol identifier



%%------------------------------------------------------------------------------
%% @doc
%% Given a raw Ethernet frame, returns its record representation.
%% @end
%%------------------------------------------------------------------------------
-spec decode(raw_eth_frame()) -> eth_frame().
decode(<<Dst:6/bytes, Src:6/bytes, TPID:2/integer-unit:8, PCP:1/integer-unit:3,
         DEI:1/integer-unit:1, VID:1/integer-unit:12, Type:2/integer-unit:8,
         Rest/binary>> = Frame) when TPID == ?'802.1Q' ->
    DataLen = size(Frame) - 22, % 22 = 6 + 6 + 2 + 2 + 2 + 4 (CRC)
    <<Data:DataLen/bytes, CRC:4/integer-unit:8>> = Rest,
    #eth{dst = mac_to_str(Dst),
         src = mac_to_str(Src),
         pcp = PCP,
         drop = DEI == 1,
         vlan_id = VID,
         type = Type,
         data = Data,
         crc =CRC,
         multicast = is_mcast_addr(Dst)};
decode(<<Dst:6/bytes, Src:6/bytes, Type:2/integer-unit:8,
         Rest/binary>> = Frame) ->
    DataLen = size(Frame) - 18, % 18 = 6 + 6 + 2 + 4 (CRC)
    <<Data:DataLen/bytes, CRC:4/integer-unit:8>> = Rest,
    #eth{dst = mac_to_str(Dst),
         src = mac_to_str(Src),
         type = Type,
         data = Data,
         crc = CRC,
         multicast = is_mcast_addr(Dst)}.

-spec is_mcast_addr(raw_mac_addr()) -> boolean().
is_mcast_addr(<<_:7/bits, LSB:1/bits, _:40/bits>> = _MACAddr) ->
    %% A MAC address is said to be of the multicast type if the least
    %% significant bit of its most significant byte is set to 1.
    LSB == <<1:1>>.

%%------------------------------------------------------------------------------
%% @doc
%% Given a record representation of an Ethernet frame, returns it in its raw
%% form.
%% @end
%%------------------------------------------------------------------------------
-spec encode(eth_frame()) -> raw_eth_frame().
encode(#eth{dst = Dst0, src = Src0, vlan_id = undefined, type = Type,
            data = Data, crc = CRC}) ->
    Dst = str_to_mac(Dst0),
    Src = str_to_mac(Src0),
    <<Dst:6/bytes, Src:6/bytes, Type:2/integer-unit:8, Data/binary,
      CRC:4/integer-unit:8>>;
encode(#eth{dst = Dst0, src = Src0, pcp = PCP, drop = DEI0, vlan_id = VID,
            type = Type, data = Data, crc = CRC}) ->
    Dst = str_to_mac(Dst0),
    Src = str_to_mac(Src0),
    DEI = if DEI0 -> 1;
             true -> 0
          end,
    <<Dst:6/bytes, Src:6/bytes, ?'802.1Q':2/integer-unit:8, PCP:1/integer-unit:3,
      DEI:1/integer-unit:1, VID:1/integer-unit:12, Type:2/integer-unit:8,
      Data/binary, CRC:4/integer-unit:8>>.


%%------------------------------------------------------------------------------
%% @doc
%% Given an Ethernet frame, returns true if it is of the multicast type.
%% Otherwise, returns false.
%% @end
%%------------------------------------------------------------------------------
-spec is_multicast(eth_frame()) -> boolean().
is_multicast(#eth{multicast = Multicast}) ->
    Multicast.

%%------------------------------------------------------------------------------
%% @doc
%% Given an Ethernet frame, returns its destination MAC address.
%% @end
%%------------------------------------------------------------------------------
-spec dst(eth_frame()) -> mac_addr().
dst(#eth{dst = Dst} = _Frame) ->
    Dst.

%%------------------------------------------------------------------------------
%% @doc
%% Given an Ethernet frame, returns its source MAC address.
%% @end
%%------------------------------------------------------------------------------
-spec src(eth_frame()) -> mac_addr().
src(#eth{src = Src} = _Frame) ->
    Src.

%%------------------------------------------------------------------------------
%% @doc
%% Given a raw MAC address, returns its string representation.
%% @end
%%------------------------------------------------------------------------------
-spec mac_to_str(raw_mac_addr()) -> mac_addr().
mac_to_str(MACAddr) ->
    mac_to_str_(MACAddr, []).

mac_to_str_(<<Bin:1/bytes, Rest/binary>>, Acc) ->
    mac_to_str_(Rest, [to_hex(Bin)| Acc]);
mac_to_str_(_, Acc) ->
    string:join(lists:reverse(Acc), ":").

to_hex(Bin) ->
    lists:flatten(
      io_lib:format(
        "~2..0s", [integer_to_list(binary:decode_unsigned(Bin), 16)])).

%%------------------------------------------------------------------------------
%% @doc
%% Given a string representation of a MAC address, returns its binary
%% representation
%% @end
%%------------------------------------------------------------------------------
-spec str_to_mac(mac_addr()) -> raw_mac_addr().
str_to_mac(MACAddr) ->
    list_to_binary(
      [ list_to_integer(S, 16) || S <- string:tokens(MACAddr, ":") ]).
