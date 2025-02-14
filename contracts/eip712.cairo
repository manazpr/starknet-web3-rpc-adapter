%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.bitwise import bitwise_and
from contracts.keccak256 import uint256_keccak
from openzeppelin.account.library import AccountCallArray

const BYTES_IN_UINT256 = 32

func fill_with_uint256{range_check_ptr}(result : Uint256*, values : felt*, values_len : felt) -> ():
    if values_len == 0:
        return ()
    end

    let (high, low) = split_felt([values])
    assert result[0] = Uint256(low, high)
    fill_with_uint256(result + 2, values + 1, values_len - 1)
    return ()
end

func map_to_uint256{range_check_ptr}(values : felt*, values_len : felt) -> (result : Uint256*):
    alloc_locals
    let (result : Uint256*) = alloc()
    fill_with_uint256(result, values, values_len)
    return (result)
end

const PREFIX = 0x1901
const PAYLOAD_HASH_HIGH = 0x47f03fc876696aac574707fcf0883786
const PAYLOAD_HASH_LOW = 0x4f820b0930851d2d35c46bb30210f667
const CALL_HASH_HIGH = 0x714eac062377e0abde0013fdf51792c0
const CALL_HASH_LOW = 0xe0e5eb253b24cbe03ed4c7aeeae37df4

# value has to be a 16 byte word
# prefix length = PREFIX_BITS
func add_prefix{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(value : felt, prefix : felt) -> (
        result : felt, overflow):
    let shifted_prefix = prefix * 2 ** 128
    # with_prefix is 18 bytes long
    let with_prefix = shifted_prefix + value
    let overflow_mask = 2 ** 16 - 1
    let (overflow) = bitwise_and(with_prefix, overflow_mask)
    let result = (with_prefix - overflow) / 2 ** 16
    return (result, overflow)
end

func encode_call{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    to : felt, selector : felt, calldata_len : felt, calldata : felt*
) -> (hash: Uint256):
    alloc_locals

    let (values : Uint256*) = alloc()
    assert values[0] = Uint256(CALL_HASH_LOW, CALL_HASH_HIGH)

    let (to_h, to_l) = split_felt(to)
    assert values[1] = Uint256(to_l, to_h)

    let (selector_h, selector_l) = split_felt(selector)
    assert values[2] = Uint256(selector_l, selector_h)

    let (calldata_uint256) = map_to_uint256(calldata, calldata_len)
    let (calldata_hash) = uint256_keccak(calldata_uint256, calldata_len * BYTES_IN_UINT256)
    assert values[3] = Uint256(calldata_hash.low, calldata_hash.high)

    let (res) = uint256_keccak(values, 4 * BYTES_IN_UINT256)

    return (res)
end

func encode_calls_loop{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    values: Uint256*,
    call_index: felt,
    call_array_len: felt,
    call_array: AccountCallArray*,
    calldata: felt*,
) -> ():
   if call_index == call_array_len:
        return ()
   end

   let call_info = call_array[call_index]
   let call_calldata = calldata + call_info.data_offset
   let (encoded) = encode_call(
        to=call_info.to,
        selector=call_info.selector,
        calldata_len=call_info.data_len,
        calldata=call_calldata,
   )
   assert values[0] = encoded

   let values = values + 2 # every uint256 = 2 felts
   encode_calls_loop(
        values,
        call_index+1,
        call_array_len,
        call_array,
        calldata,
   )

   return ()
end


func encode_call_array{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    call_array_len: felt,
    call_array: AccountCallArray*,
    calldata: felt*,
) -> (
    calls_hash: Uint256
):
    alloc_locals
    let (values : Uint256*) = alloc()

    encode_calls_loop(
        values=values,
        call_index=0,
        call_array_len=call_array_len,
        call_array=call_array,
        calldata=calldata,
    )

    let (calls_hash) = uint256_keccak(values, call_array_len * BYTES_IN_UINT256)

    return (calls_hash)
end

func get_hash{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    call_array_len: felt,
    call_array: AccountCallArray*,
    calldata: felt*,
    nonce: felt,
    max_fee: felt,
    version: felt,
    domain_hash: Uint256,
) -> (
    hashed_msg : Uint256
):
    alloc_locals
    let (calls_hash) = encode_call_array(call_array_len, call_array, calldata)

    let (encoded_data : Uint256*) = alloc()

    assert encoded_data[0] = Uint256(PAYLOAD_HASH_LOW, PAYLOAD_HASH_HIGH)

    let (nonce_h, nonce_l) = split_felt(nonce)
    assert encoded_data[1] = Uint256(nonce_l, nonce_h)

    let (max_fee_h, max_fee_l) = split_felt(max_fee)
    assert encoded_data[2] = Uint256(max_fee_l, max_fee_h)

    let (version_h, version_l) = split_felt(version)
    assert encoded_data[3] = Uint256(version_l, version_h)

    assert encoded_data[4] = Uint256(calls_hash.low, calls_hash.high)
    let (data_hash) = uint256_keccak(encoded_data, 5 * BYTES_IN_UINT256)

    let prefix = PREFIX
    let (w1, prefix) = add_prefix(domain_hash.high, prefix)
    let (w0, prefix) = add_prefix(domain_hash.low, prefix)
    let (w3, prefix) = add_prefix(data_hash.high, prefix)
    let (w2, overflow) = add_prefix(data_hash.low, prefix)
    let (signable_bytes : Uint256*) = alloc()
    assert signable_bytes[0] = Uint256(w0, w1)
    assert signable_bytes[1] = Uint256(w2, w3)
    assert signable_bytes[2] = Uint256(overflow, 0)
    let (res) = uint256_keccak(signable_bytes, BYTES_IN_UINT256 + BYTES_IN_UINT256 + 2)
    return (res)
end
