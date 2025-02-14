import pytest
from starkware.starknet.testing.objects import StarknetContractCall
from starkware.starknet.testing.starknet import Starknet
from Crypto.Hash import keccak

from contracts.test_utils import deploy_contract_with_hints, to_uint256

code = """
%lang starknet

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from contracts.keccak256 import uint256_keccak
from starkware.cairo.common.alloc import alloc

@view
func uint256_keccak_view{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
        v0: Uint256,
        v1: Uint256,
        v2: Uint256,
        v3: Uint256,
        v4: Uint256,
        bytes: felt,
    ) -> (res: Uint256):
    alloc_locals

    let (values: Uint256*) = alloc()
    assert values[0] = v0
    assert values[1] = v1
    assert values[2] = v2
    assert values[3] = v3
    assert values[4] = v4

    let (res) = uint256_keccak(values, bytes)
    return (res)
end
"""

def keccak256(bytes):
    k = keccak.new(digest_bits=256)
    k.update(bytes)
    return int.from_bytes(k.digest(), "big")

@pytest.mark.asyncio
async def test_uint256_keccak():
    starknet = await Starknet.empty()
    account = await deploy_contract_with_hints(starknet, code, [])

    # 160 bytes
    values = [
        2 ** 256 - 19,
        1,
        0,
        113,
        2 ** 128 + 15
    ]
    expected = keccak256(b"".join([v.to_bytes(32, "big") for v in values]))

    call = await account.uint256_keccak_view(
        *[to_uint256(v) for v in values], 32*5
    ).call()

    info: StarknetContractCall = call.call_info
    print("KECCAK 160 CAIRO USAGE", info.cairo_usage)
    assert call.result[0] == to_uint256(expected)

    # 34 bytes
    values = [
        2 ** 256 - 19,
        1234,
        0,
        0,
        0
    ]
    expected = keccak256(b"".join([values[0].to_bytes(32, "big"), values[1].to_bytes(2, "big")]))

    call = await account.uint256_keccak_view(
        *[to_uint256(v) for v in values], 32+2
    ).call()

    info: StarknetContractCall = call.call_info
    print("KECCAK 34 bytes", info.cairo_usage)
    assert call.result[0] == to_uint256(expected)
